defmodule OfficeBooking.Messaging.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias OfficeBooking.{Accounts.User, Rooms.Room, Bookings.Booking}

  schema "messages" do
    field :subject, :string
    field :content, :string
    field :read_at, :utc_datetime
    field :action_type, :string        # "booking_transfer_request", "booking_transfer_response"
    field :action_data, :map           # Store booking IDs, transfer details
    field :action_status, :string      # "pending", "approved", "declined", "completed"

    belongs_to :from_user, User
    belongs_to :to_user, User
    belongs_to :room, Room
    belongs_to :booking, Booking

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:subject, :content, :read_at, :from_user_id, :to_user_id, :room_id, :booking_id,:action_type, :action_data, :action_status])
    |> validate_required([:subject, :content, :from_user_id, :to_user_id])
    |> validate_length(:subject, min: 1, max: 200)
    |> validate_length(:content, min: 1, max: 5000)
    |> validate_inclusion(:action_type, [nil, "booking_transfer_request", "booking_transfer_response"])
    |> validate_inclusion(:action_status, ["pending", "approved", "declined", "completed"])
    |> validate_different_users()
    |> foreign_key_constraint(:from_user_id)
    |> foreign_key_constraint(:to_user_id)
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:booking_id)
  end

  defp validate_different_users(changeset) do
    from_user_id = get_field(changeset, :from_user_id)
    to_user_id = get_field(changeset, :to_user_id)

    if from_user_id && to_user_id && from_user_id == to_user_id do
      add_error(changeset, :to_user_id, "cannot send message to yourself")
    else
      changeset
    end
  end

  @doc """
  Returns whether the message has been read
  """
  def read?(%__MODULE__{read_at: read_at}), do: not is_nil(read_at)

  # Helper functions for action messages
  def booking_transfer_request_subject(%OfficeBooking.Rooms.Room{} = room) do
    "Room Transfer Request: #{room.name}"
  end

  def booking_transfer_request_subject(%OfficeBooking.Bookings.Booking{} = booking) do
    booking = OfficeBooking.Repo.preload(booking, :room)
    "Booking Transfer Request: #{booking.room.name} - #{format_datetime(booking.start_datetime)}"
  end

  def is_action_message?(%__MODULE__{action_type: action_type}) do
    not is_nil(action_type)
  end

  def transfer_request?(%__MODULE__{action_type: "booking_transfer_request"}), do: true
  def transfer_request?(_), do: false

  def pending_action?(%__MODULE__{action_status: "pending"}), do: true
  def pending_action?(_), do: false

  @doc """
  Formats message timestamp for display
  """
  def format_timestamp(%__MODULE__{inserted_at: timestamp}) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.shift_zone!("Asia/Karachi")
    |> Calendar.strftime("%B %d, %Y at %I:%M %p PKT")
  end

  @doc """
  Formats datetime for display, handling different input types.
  """
  # Clause for handling string input (the one causing the crash)
  def format_datetime(datetime) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, datetime_struct, _offset} ->
        format_datetime(datetime_struct)
      {:error, _reason} ->
        # Return a descriptive string or the original value if parsing fails
        datetime
    end
  end

  # Clause for handling NaiveDateTime struct (the expected input)
  def format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Asia/Karachi")
    |> Calendar.strftime("%B %d, %Y at %I:%M %p PKT")
  end

  # Clause for handling any other unexpected input gracefully
  def format_datetime(datetime) do
    # You might want to log this to debug unexpected data types
    IO.warn("format_datetime received unexpected data type: #{inspect(datetime)}")
    "Invalid Time"
  end

  @doc """
  Generates a room negotiation subject
  """
  def room_negotiation_subject(%Room{name: room_name}) do
    "Room Request: #{room_name}"
  end

  @doc """
  Generates a booking negotiation subject
  """
  def booking_negotiation_subject(%OfficeBooking.Bookings.Booking{} = booking) do
    booking = OfficeBooking.Repo.preload(booking, :room)
    "Booking Discussion: #{booking.room.name} - #{format_datetime(booking.start_datetime)}"
  end
end
