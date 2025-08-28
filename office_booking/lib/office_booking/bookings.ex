defmodule OfficeBooking.Bookings do
  @moduledoc """
  The Bookings context.
  """

  import Ecto.Query, warn: false
  alias OfficeBooking.Repo

  alias OfficeBooking.Bookings.Booking
  alias OfficeBooking.{Accounts.User, Rooms.Room}


  @doc """
  Returns the list of bookings for a user.
  """
  def list_user_bookings(%User{id: user_id}) do
    Booking
    |> where([b], b.user_id == ^user_id)
    |> where([b], b.status == "confirmed")
    |> order_by([b], asc: b.start_datetime)
    |> preload([:room, :user])
    |> Repo.all()
  end

  @doc """
  Returns the list of active bookings for a room.
  """
  def list_room_bookings(%Room{id: room_id}) do
    now = DateTime.utc_now()

    Booking
    |> where([b], b.room_id == ^room_id)
    |> where([b], b.status == "confirmed")
    |> where([b], b.end_datetime > ^now)
    |> order_by([b], asc: b.start_datetime)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Returns all bookings (admin only).
  """
  def list_all_bookings do
    Booking
    |> order_by([b], desc: b.start_datetime)
    |> preload([:room, :user])
    |> Repo.all()
  end


  @doc """
  Returns the list of bookings.

  ## Examples

      iex> list_bookings()
      [%Booking{}, ...]

  """
  # def list_bookings do
  #   Repo.all(Booking)
  # end

  @doc """
  Gets a single booking.

  Raises `Ecto.NoResultsError` if the Booking does not exist.

  ## Examples

      iex> get_booking!(123)
      %Booking{}

      iex> get_booking!(456)
      ** (Ecto.NoResultsError)

  """
  def get_booking!(id) do
    Booking
    |> preload([:room, :user])
    |> Repo.get!(id)
  end


  @doc """
  Gets a single booking owned by user.
  """
  def get_user_booking!(%User{id: user_id}, booking_id) do
    Booking
    |> where([b], b.user_id == ^user_id)
    |> preload([:room, :user])
    |> Repo.get!(booking_id)
  end

  @doc """
  Creates a booking with conflict checking.
  """
  def create_booking(attrs \\ %{}) do
    with {:ok, booking} <- %Booking{}
                           |> Booking.changeset(attrs)
                           |> Repo.insert() do
      # Broadcast the booking creation
      booking = Repo.preload(booking, [:room, :user])
      broadcast_booking_change(booking, :created)
      {:ok, booking}
    end
  end

  @doc """
  Creates a booking as admin (bypasses some validations).
  """
  def create_booking_as_admin(attrs \\ %{}) do
    with {:ok, booking} <- %Booking{}
                           |> Booking.admin_changeset(attrs)
                           |> Repo.insert() do
      booking = Repo.preload(booking, [:room, :user])
      broadcast_booking_change(booking, :created)
      {:ok, booking}
    end
  end

  @doc """
  Updates a booking.

  ## Examples

      iex> update_booking(booking, %{field: new_value})
      {:ok, %Booking{}}

      iex> update_booking(booking, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_booking(%Booking{} = booking, attrs, admin \\ false) do
    changeset = if admin do
      Booking.admin_changeset(booking, attrs)
    else
      Booking.changeset(booking, attrs)
    end

    with {:ok, booking} <- Repo.update(changeset) do
      booking = Repo.preload(booking, [:room, :user], force: true)
      broadcast_booking_change(booking, :updated)
      {:ok, booking}
    end
  end

  @doc """
  Cancels a booking.
  """
  def cancel_booking(%Booking{} = booking) do
    update_booking(booking, %{status: "cancelled"})
  end

  @doc """
  Deletes a booking.

  ## Examples

      iex> delete_booking(booking)
      {:ok, %Booking{}}

      iex> delete_booking(booking)
      {:error, %Ecto.Changeset{}}

  """
  @doc """
  Deletes a booking (admin only).
  """
  def delete_booking(%Booking{} = booking) do
    case Repo.delete(booking) do
      {:ok, booking} ->
        broadcast_booking_change(booking, :deleted)
        {:ok, booking}
      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking booking changes.

  ## Examples

      iex> change_booking(booking)
      %Ecto.Changeset{data: %Booking{}}

  """
  def change_booking(%Booking{} = booking, attrs \\ %{}) do
    Booking.changeset(booking, attrs)
  end

  # Conflict detection and availability
  @doc """
  Checks if a room is available for the given time period.
  """
  def room_available?(%Room{id: room_id}, start_datetime, end_datetime, exclude_booking_id \\ nil) do
    query = from b in Booking,
      where: b.room_id == ^room_id,
      where: b.status == "confirmed",
      where: not (b.end_datetime <= ^start_datetime or b.start_datetime >= ^end_datetime)

    query = if exclude_booking_id do
      where(query, [b], b.id != ^exclude_booking_id)
    else
      query
    end

    Repo.aggregate(query, :count) == 0
  end

  @doc """
  Gets conflicting bookings for a room and time period.
  """
  def get_conflicting_bookings(%Room{id: room_id}, start_datetime, end_datetime) do
    Booking
    |> where([b], b.room_id == ^room_id)
    |> where([b], b.status == "confirmed")
    |> where([b], not (b.end_datetime <= ^start_datetime or b.start_datetime >= ^end_datetime))
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Gets current booking for a room (if any).
  """
  def get_current_booking(%Room{id: room_id}) do
    now = DateTime.utc_now()

    Booking
    |> where([b], b.room_id == ^room_id)
    |> where([b], b.status == "confirmed")
    |> where([b], b.start_datetime <= ^now and b.end_datetime > ^now)
    |> preload([:user])
    |> Repo.one()
  end

  @doc """
  Gets upcoming bookings for a room (next 24 hours).
  """
  def get_upcoming_bookings(%Room{id: room_id}) do
    now = DateTime.utc_now()
    tomorrow = DateTime.add(now, 24 * 60 * 60)

    Booking
    |> where([b], b.room_id == ^room_id)
    |> where([b], b.status == "confirmed")
    |> where([b], b.start_datetime > ^now and b.start_datetime <= ^tomorrow)
    |> order_by([b], asc: b.start_datetime)
    |> preload([:user])
    |> Repo.all()
  end

  # Real-time updates via PubSub
  defp broadcast_booking_change(%Booking{room_id: room_id} = booking, action) do
    Phoenix.PubSub.broadcast(
      OfficeBooking.PubSub,
      "room_bookings:#{room_id}",
      {action, booking}
    )

    Phoenix.PubSub.broadcast(
      OfficeBooking.PubSub,
      "user_bookings:#{booking.user_id}",
      {action, booking}
    )

    Phoenix.PubSub.broadcast(
      OfficeBooking.PubSub,
      "all_bookings",
      {action, booking}
    )
  end

  @doc """
  Subscribes to booking updates for a room.
  """
  def subscribe_to_room_bookings(room_id) do
    Phoenix.PubSub.subscribe(OfficeBooking.PubSub, "room_bookings:#{room_id}")
  end

  @doc """
  Subscribes to booking updates for a user.
  """
  def subscribe_to_user_bookings(user_id) do
    Phoenix.PubSub.subscribe(OfficeBooking.PubSub, "user_bookings:#{user_id}")
  end

  @doc """
  Subscribes to all booking updates (admin only).
  """
  def subscribe_to_all_bookings do
    Phoenix.PubSub.subscribe(OfficeBooking.PubSub, "all_bookings")
  end

  # Time and scheduling helpers
  @doc """
  Converts local CET datetime to UTC.
  """
  def cet_to_utc(naive_datetime) do
    case DateTime.new(naive_datetime, "Europe/Berlin") do
      {:ok, cet_datetime} -> DateTime.shift_zone!(cet_datetime, "Etc/UTC")
      {:error, _} -> nil
    end
  end

  @doc """
  Converts UTC datetime to CET.
  """
  def utc_to_cet(utc_datetime) do
    DateTime.shift_zone!(utc_datetime, "Europe/Berlin")
  end

  @doc """
  Generates available time slots for a room on a given date.
  """
  def available_time_slots(%Room{} = room, date) do
    # Generate 30-minute slots from 10 AM to 10 PM CET
    start_time = ~T[10:00:00]
    end_time = ~T[22:00:00]

    slots = generate_time_slots(date, start_time, end_time, 30)

    # Filter out booked slots
    existing_bookings = list_room_bookings(room)
    |> Enum.filter(fn booking ->
      booking_date = booking.start_datetime |> utc_to_cet() |> DateTime.to_date()
      Date.compare(booking_date, date) == :eq
    end)

    Enum.reject(slots, fn {slot_start, slot_end} ->
      Enum.any?(existing_bookings, fn booking ->
        booking_start = utc_to_cet(booking.start_datetime)
        booking_end = utc_to_cet(booking.end_datetime)

        # Check if slot overlaps with booking
        not (DateTime.compare(slot_end, booking_start) != :gt or
             DateTime.compare(slot_start, booking_end) != :lt)
      end)
    end)
  end

  defp generate_time_slots(date, start_time, end_time, interval_minutes) do
    start_datetime = DateTime.new!(date, start_time, "Europe/Berlin")
    end_datetime = DateTime.new!(date, end_time, "Europe/Berlin")

    generate_slots(start_datetime, end_datetime, interval_minutes, [])
  end

  defp generate_slots(current, end_datetime, interval_minutes, acc) when current >= end_datetime do
    Enum.reverse(acc)
  end

  defp generate_slots(current, end_datetime, interval_minutes, acc) do
    slot_end = DateTime.add(current, interval_minutes * 60)

    if DateTime.compare(slot_end, end_datetime) != :gt do
      generate_slots(
        slot_end,
        end_datetime,
        interval_minutes,
        [{current, slot_end} | acc]
      )
    else
      Enum.reverse(acc)
    end
  end
end
