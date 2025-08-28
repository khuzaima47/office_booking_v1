defmodule OfficeBooking.Bookings.Booking do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias OfficeBooking.{Accounts.User, Rooms.Room}

  @statuses ["confirmed", "cancelled"]

  schema "bookings" do
    field :start_datetime, :utc_datetime
    field :end_datetime, :utc_datetime
    field :title, :string
    field :description, :string
    field :status, :string, default: "confirmed"

    belongs_to :user, User
    belongs_to :room, Room

    timestamps()
  end

  @doc false
  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [:start_datetime, :end_datetime, :title, :description, :status, :user_id, :room_id])
    |> validate_required([:start_datetime, :end_datetime, :title, :user_id, :room_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:description, max: 1000)
    |> validate_datetime_order()
    |> validate_business_hours()
    |> validate_advance_booking_limit()
    |> validate_minimum_duration()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:room_id)
    |> unique_constraint([:room_id, :start_datetime, :end_datetime],
                        name: :bookings_no_overlap_index,
                        message: "Room is already booked for this time period")
  end

  @doc """
  Changeset for admin operations (bypasses some validations)
  """
  def admin_changeset(booking, attrs) do
    booking
    |> cast(attrs, [:start_datetime, :end_datetime, :title, :description, :status, :user_id, :room_id])
    |> validate_required([:start_datetime, :end_datetime, :title, :user_id, :room_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:description, max: 1000)
    |> validate_datetime_order()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:room_id)
  end

  # Custom validations
  defp validate_datetime_order(changeset) do
    start_dt = get_field(changeset, :start_datetime)
    end_dt = get_field(changeset, :end_datetime)

    if start_dt && end_dt && DateTime.compare(start_dt, end_dt) != :lt do
      add_error(changeset, :end_datetime, "must be after start time")
    else
      changeset
    end
  end

  defp validate_business_hours(changeset) do
    start_dt = get_field(changeset, :start_datetime)
    end_dt = get_field(changeset, :end_datetime)

    cond do
      is_nil(start_dt) || is_nil(end_dt) ->
        changeset

      !valid_business_hour?(start_dt) ->
        add_error(changeset, :start_datetime, "must be within business hours (10 AM - 10 PM CET)")

      !valid_business_hour?(end_dt) ->
        add_error(changeset, :end_datetime, "must be within business hours (10 AM - 10 PM CET)")

      true ->
        changeset
    end
  end

  defp validate_advance_booking_limit(changeset) do
    start_dt = get_field(changeset, :start_datetime)

    if start_dt do
      now = DateTime.utc_now()
      cet_now = DateTime.shift_zone!(now, "Europe/Berlin")
      cet_start = DateTime.shift_zone!(start_dt, "Europe/Berlin")

      # Calculate days difference
      days_diff = Date.diff(DateTime.to_date(cet_start), DateTime.to_date(cet_now))

      if days_diff > 2 do
        add_error(changeset, :start_datetime, "cannot book more than 2 days in advance")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_minimum_duration(changeset) do
    start_dt = get_field(changeset, :start_datetime)
    end_dt = get_field(changeset, :end_datetime)

    if start_dt && end_dt do
      duration_minutes = DateTime.diff(end_dt, start_dt, :minute)

      if duration_minutes < 30 do
        add_error(changeset, :end_datetime, "booking must be at least 30 minutes long")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp valid_business_hour?(datetime) do
    cet_time = DateTime.shift_zone!(datetime, "Europe/Berlin")
    hour = cet_time.hour
    hour >= 10 && hour <= 22
  end

  # Helper functions
  @doc """
  Returns whether the booking is active (confirmed and current)
  """
  def active?(%__MODULE__{status: "confirmed", end_datetime: end_dt}) do
    DateTime.compare(end_dt, DateTime.utc_now()) == :gt
  end
  def active?(_), do: false

  @doc """
  Returns whether the booking is currently in progress
  """
  def in_progress?(%__MODULE__{status: "confirmed", start_datetime: start_dt, end_datetime: end_dt}) do
    now = DateTime.utc_now()
    DateTime.compare(start_dt, now) != :gt && DateTime.compare(end_dt, now) == :gt
  end
  def in_progress?(_), do: false

  @doc """
  Returns the duration in minutes
  """
  def duration_minutes(%__MODULE__{start_datetime: start_dt, end_datetime: end_dt}) do
    DateTime.diff(end_dt, start_dt, :minute)
  end

  @doc """
  Formats datetime for display in CET timezone
  """
  def format_datetime(datetime) do
    datetime
    |> DateTime.shift_zone!("Europe/Berlin")
    |> Calendar.strftime("%B %d, %Y at %I:%M %p CET")
  end

  @doc """
  Formats time only for display in CET timezone
  """
  def format_time(datetime) do
    datetime
    |> DateTime.shift_zone!("Europe/Berlin")
    |> Calendar.strftime("%I:%M %p")
  end
end
