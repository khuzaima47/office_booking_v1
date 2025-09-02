defmodule OfficeBooking.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :naive_datetime
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :department, :string
    field :is_admin, :boolean, default: false

    has_many :bookings, OfficeBooking.Bookings.Booking, on_delete: :delete_all
    has_many :sent_messages, OfficeBooking.Messaging.Message, foreign_key: :from_user_id, on_delete: :delete_all
    has_many :received_messages, OfficeBooking.Messaging.Message, foreign_key: :to_user_id, on_delete: :delete_all

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :first_name, :last_name, :phone, :department])
    |> validate_required([:email, :password, :first_name, :last_name])
    |> validate_first_name()
    |> validate_last_name()
    |> validate_phone()
    |> validate_department()
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc """
  A user changeset for changing the profile information.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :phone, :department])
    |> validate_required([:first_name, :last_name])
    |> validate_first_name()
    |> validate_last_name()
    |> validate_phone()
    |> validate_department()
  end

  @doc """
  A user changeset for changing admin status (admin only).
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:is_admin])
    |> validate_required([:is_admin])
  end

   defp validate_first_name(changeset) do
    changeset
    |> validate_length(:first_name, min: 1, max: 50)
    |> validate_format(:first_name, ~r/^[a-zA-Z\s]+$/, message: "can only contain letters and spaces")
  end

  defp validate_last_name(changeset) do
    changeset
    |> validate_length(:last_name, min: 1, max: 50)
    |> validate_format(:last_name, ~r/^[a-zA-Z\s]+$/, message: "can only contain letters and spaces")
  end

  defp validate_phone(changeset) do
    case get_field(changeset, :phone) do
      nil -> changeset
      "" -> changeset
      _phone ->
        changeset
        |> validate_length(:phone, min: 10, max: 20)
        |> validate_format(:phone, ~r/^[+\-\d\s()]+$/, message: "invalid phone number format")
    end
  end

  defp validate_department(changeset) do
    case get_field(changeset, :department) do
      nil -> changeset
      "" -> changeset
      _dept -> validate_length(changeset, :department, min: 2, max: 100)
    end
  end

  @doc """
  Returns the full name of the user by combining first_name and last_name.
  """
  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end
  

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, OfficeBooking.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%OfficeBooking.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
