defmodule OfficeBooking.Messaging do
  @moduledoc """
  The Messaging context for user communication and negotiation.
  """

  import Ecto.Query, warn: false
  alias OfficeBooking.Repo
  alias OfficeBooking.Messaging.Message
  alias OfficeBooking.{Accounts.User, Rooms.Room, Bookings.Booking}

  # Message CRUD operations
  @doc """
  Returns the list of messages for a user (sent and received).
  """
  def list_user_messages(%User{id: user_id}) do
    Message
    |> where([m], m.from_user_id == ^user_id or m.to_user_id == ^user_id)
    |> order_by([m], desc: m.inserted_at)
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.all()
  end

  @doc """
  Returns conversations grouped by participants.
  """
  def list_user_conversations(%User{id: user_id}) do
    # Get all messages involving this user
    messages = list_user_messages(%User{id: user_id})

    # Group by conversation (other participant)
    messages
    |> Enum.group_by(fn message ->
      if message.from_user_id == user_id do
        message.to_user_id
      else
        message.from_user_id
      end
    end)
    |> Enum.map(fn {other_user_id, msgs} ->
      latest_message = List.first(msgs)
      other_user = if latest_message.from_user_id == user_id do
        latest_message.to_user
      else
        latest_message.from_user
      end

      unread_count = msgs
      |> Enum.filter(fn msg ->
        msg.to_user_id == user_id && is_nil(msg.read_at)
      end)
      |> length()

      %{
        other_user: other_user,
        latest_message: latest_message,
        unread_count: unread_count,
        message_count: length(msgs)
      }
    end)
    |> Enum.sort_by(& &1.latest_message.inserted_at, :desc)
  end

  @doc """
  Returns conversation between two users.
  """
  def get_conversation(%User{id: user1_id}, %User{id: user2_id}) do
    Message
    |> where([m],
      (m.from_user_id == ^user1_id and m.to_user_id == ^user2_id) or
      (m.from_user_id == ^user2_id and m.to_user_id == ^user1_id)
    )
    |> order_by([m], asc: m.inserted_at)
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.all()
  end

  @doc """
  Returns unread message count for a user.
  """
  def unread_count(%User{id: user_id}) do
    Message
    |> where([m], m.to_user_id == ^user_id and is_nil(m.read_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets a single message.
  """
  def get_message!(id) do
    Message
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.get!(id)
  end

  @doc """
  Creates a message.
  """
  def create_message(attrs \\ %{}) do
    with {:ok, message} <- %Message{}
                           |> Message.changeset(attrs)
                           |> Repo.insert() do
      message = Repo.preload(message, [:from_user, :to_user, :room, :booking])
      broadcast_message(message, :created)
      {:ok, message}
    end
  end

  @doc """
  Creates a room negotiation message.
  """
  def create_room_negotiation_message(%User{} = from_user, %User{} = to_user, %Room{} = room, content) do
    attrs = %{
      from_user_id: from_user.id,
      to_user_id: to_user.id,
      room_id: room.id,
      subject: Message.room_negotiation_subject(room),
      content: content
    }

    create_message(attrs)
  end

  @doc """
  Creates a booking negotiation message.
  """
  def create_booking_negotiation_message(%User{} = from_user, %User{} = to_user, %Booking{} = booking, content) do
    booking = Repo.preload(booking, :room)

    attrs = %{
      from_user_id: from_user.id,
      to_user_id: to_user.id,
      room_id: booking.room_id,
      booking_id: booking.id,
      subject: Message.booking_negotiation_subject(booking),
      content: content
    }

    create_message(attrs)
  end

  @doc """
  Updates a message.
  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks a message as read.
  """
  def mark_as_read(%Message{} = message) do
    case update_message(message, %{read_at: DateTime.utc_now()}) do
      {:ok, message} ->
        broadcast_message(message, :read)
        {:ok, message}
      error ->
        error
    end
  end

  @doc """
  Marks all messages in a conversation as read for a user.
  """
  def mark_conversation_as_read(%User{id: user_id}, %User{id: other_user_id}) do
    now = DateTime.utc_now()

    {count, _} =
      Message
      |> where([m], m.from_user_id == ^other_user_id and m.to_user_id == ^user_id and is_nil(m.read_at))
      |> Repo.update_all(set: [read_at: now, updated_at: now])

    if count > 0 do
      broadcast_conversation_read(user_id, other_user_id)
    end

    count
  end

  @doc """
  Deletes a message.
  """
  def delete_message(%Message{} = message) do
    case Repo.delete(message) do
      {:ok, message} ->
        broadcast_message(message, :deleted)
        {:ok, message}
      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  # Real-time messaging via PubSub
  defp broadcast_message(%Message{to_user_id: to_user_id} = message, action) do
    Phoenix.PubSub.broadcast(
      OfficeBooking.PubSub,
      "user_messages:#{to_user_id}",
      {action, message}
    )

    Phoenix.PubSub.broadcast(
      OfficeBooking.PubSub,
      "user_messages:#{message.from_user_id}",
      {action, message}
    )
  end

  defp broadcast_conversation_read(user_id, other_user_id) do
    Phoenix.PubSub.broadcast(
      OfficeBooking.PubSub,
      "user_messages:#{other_user_id}",
      {:conversation_read, user_id}
    )
  end

  @doc """
  Subscribes to message updates for a user.
  """
  def subscribe_to_user_messages(user_id) do
    Phoenix.PubSub.subscribe(OfficeBooking.PubSub, "user_messages:#{user_id}")
  end

  # Search and filter functions
  @doc """
  Searches messages by content.
  """
  def search_user_messages(%User{id: user_id}, query) when is_binary(query) do
    search_term = "%#{query}%"

    Message
    |> where([m], m.from_user_id == ^user_id or m.to_user_id == ^user_id)
    |> where([m], ilike(m.subject, ^search_term) or ilike(m.content, ^search_term))
    |> order_by([m], desc: m.inserted_at)
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.all()
  end

  @doc """
  Gets messages related to a specific room.
  """
  def get_room_messages(%Room{id: room_id}) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], desc: m.inserted_at)
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.all()
  end

  @doc """
  Gets messages related to a specific booking.
  """
  def get_booking_messages(%Booking{id: booking_id}) do
    Message
    |> where([m], m.booking_id == ^booking_id)
    |> order_by([m], desc: m.inserted_at)
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.all()
  end


  @doc """
  Creates a booking transfer request message with validation.
  """
  def create_booking_transfer_request(%User{} = requester, %Booking{} = target_booking, content) do
    target_booking = Repo.preload(target_booking, [:user, :room])

    # Validate the transfer request is allowed
    case validate_transfer_request(requester, target_booking) do
      :ok ->
        attrs = %{
          from_user_id: requester.id,
          to_user_id: target_booking.user_id,
          room_id: target_booking.room_id,
          booking_id: target_booking.id,
          subject: Message.booking_transfer_request_subject(target_booking),
          content: content,
          action_type: "booking_transfer_request",
          action_data: %{
            "target_booking_id" => target_booking.id,
            "requester_id" => requester.id,
            "room_name" => target_booking.room.name,
            "booking_start" => target_booking.start_datetime,
            "booking_end" => target_booking.end_datetime
          },
          action_status: "pending"
        }

        create_message(attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validation function to OfficeBooking.Messaging
  defp validate_transfer_request(%User{} = requester, %Booking{} = booking) do
    minutes_until_start = DateTime.diff(booking.start_datetime, DateTime.utc_now(), :minute)
    cond do
      # Can't transfer your own booking
      booking.user_id == requester.id ->
        {:error, "You cannot request transfer of your own booking"}

      # Booking must be confirmed
      booking.status != "confirmed" ->
        {:error, "Can only request transfer of confirmed bookings"}

      # Must be at least 5 minutes before the meeting
      minutes_until_start = DateTime.diff(booking.start_datetime, DateTime.utc_now(), :minute)
      minutes_until_start < 10 ->
        if DateTime.compare(booking.start_datetime, DateTime.utc_now()) == :lt do
          {:error, "Cannot request transfer of a meeting that has already started"}
        else
          {:error, "Cannot request transfer less than 5 minutes before the meeting starts"}
        end

      # Meeting has already ended
      DateTime.compare(booking.end_datetime, DateTime.utc_now()) == :lt ->
        {:error, "Cannot request transfer of a past meeting"}

      true ->
        :ok
    end
  end

  @doc """
  Processes a booking transfer response (approve/decline).
  """
  def process_booking_transfer_response(%Message{} = transfer_request, %User{} = responder, response)
      when response in ["approved", "declined"] do

    if transfer_request.to_user_id != responder.id do
      {:error, :unauthorized}
    else
      Repo.transaction(fn ->
        # Update the original transfer request message
        {:ok, updated_message} = update_message(transfer_request, %{action_status: response})

        # Create response message
        response_content = case response do
          "approved" -> "I've approved your room transfer request. The booking will be transferred to you."
          "declined" -> "I'm sorry, but I need to decline your room transfer request."
        end

        response_attrs = %{
          from_user_id: responder.id,
          to_user_id: transfer_request.from_user_id,
          room_id: transfer_request.room_id,
          booking_id: transfer_request.booking_id,
          subject: "Re: #{transfer_request.subject}",
          content: response_content,
          action_type: "booking_transfer_response",
          action_data: Map.put(transfer_request.action_data, "response", response),
          action_status: response
        }

        {:ok, response_message} = create_message(response_attrs)

        # If approved, transfer the booking
        if response == "approved" do
          case transfer_booking(transfer_request) do
            {:ok, _} ->
              # Update both messages to completed
              update_message(updated_message, %{action_status: "completed"})
              update_message(response_message, %{action_status: "completed"})
              {:ok, response_message}
            {:error, reason} ->
              Repo.rollback(reason)
          end
        else
          {:ok, response_message}
        end
      end)
    end
  end

  @doc """
  Transfers a booking from one user to another based on a transfer request message.
  """
  defp transfer_booking(%Message{action_data: action_data}) do
    target_booking_id = action_data["target_booking_id"]
    new_owner_id = action_data["requester_id"]

    # Get the current booking
    booking = OfficeBooking.Bookings.get_booking!(target_booking_id)

    # Use the dedicated transfer function that bypasses datetime validation
    OfficeBooking.Bookings.transfer_booking_ownership(booking, new_owner_id)
  end

  @doc """
  Gets pending transfer requests for a user.
  """
  def get_pending_transfer_requests(%User{id: user_id}) do
    Message
    |> where([m], m.to_user_id == ^user_id)
    |> where([m], m.action_type == "booking_transfer_request")
    |> where([m], m.action_status == "pending")
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.all()
  end

  @doc """
  Gets transfer requests sent by a user.
  """
  def get_sent_transfer_requests(%User{id: user_id}) do
    Message
    |> where([m], m.from_user_id == ^user_id)
    |> where([m], m.action_type == "booking_transfer_request")
    |> order_by([m], desc: m.inserted_at)
    |> preload([:from_user, :to_user, :room, :booking])
    |> Repo.all()
  end

end
