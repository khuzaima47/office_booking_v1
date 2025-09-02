defmodule OfficeBookingWeb.MessageLive.Conversation do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.{Messaging, Accounts}
  alias OfficeBooking.Messaging.Message

  @impl true
  def mount(%{"user_id" => other_user_id}, _session, socket) do
    if socket.assigns.current_user do
      other_user = Accounts.get_user!(other_user_id)
      current_user = socket.assigns.current_user

      # Subscribe to message updates
      Messaging.subscribe_to_user_messages(current_user.id)

      # Mark conversation as read
      Messaging.mark_conversation_as_read(current_user, other_user)

      socket =
        socket
        |> assign(:page_title, "Chat with #{Accounts.User.full_name(other_user)}")
        |> assign(:other_user, other_user)
        |> assign(:current_user, current_user)
        |> load_conversation()
        |> assign_form()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => message_params}, socket) do
    full_params = Map.merge(message_params, %{
      "from_user_id" => socket.assigns.current_user.id,
      "to_user_id" => socket.assigns.other_user.id
    })

    case Messaging.create_message(full_params) do
      {:ok, _message} ->
        socket =
          socket
          |> load_conversation()
          |> assign_form()
          |> push_event("scroll_to_bottom", %{})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_message", %{"message" => message_params}, socket) do
    changeset =
      %Message{}
      |> Message.changeset(message_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  # Handle real-time message updates
  @impl true
  def handle_info({:created, message}, socket) do
    # Only update if the message is part of this conversation
    if message_in_conversation?(message, socket) do
      # Mark as read if it's from the other user
      if message.from_user_id == socket.assigns.other_user.id do
        Messaging.mark_as_read(message)
      end

      socket =
        socket
        |> load_conversation()
        |> push_event("scroll_to_bottom", %{})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({action, _message}, socket) when action in [:read, :deleted] do
    socket = load_conversation(socket)
    {:noreply, socket}
  end

  defp message_in_conversation?(message, socket) do
    current_user_id = socket.assigns.current_user.id
    other_user_id = socket.assigns.other_user.id

    (message.from_user_id == current_user_id && message.to_user_id == other_user_id) ||
    (message.from_user_id == other_user_id && message.to_user_id == current_user_id)
  end

  defp load_conversation(socket) do
    messages = Messaging.get_conversation(socket.assigns.current_user, socket.assigns.other_user)
    assign(socket, :messages, messages)
  end

  defp assign_form(socket) do
    changeset = Message.changeset(%Message{}, %{})
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def handle_event("approve_transfer", %{"message_id" => message_id}, socket) do
    message = Messaging.get_message!(message_id)

    case Messaging.process_booking_transfer_response(message, socket.assigns.current_user, "approved") do
      {:ok, _response_message} ->
        # Refresh messages to show updated status
        messages = Messaging.get_conversation(socket.assigns.current_user, socket.assigns.other_user)

        {:noreply,
        socket
        |> assign(:messages, messages)
        |> put_flash(:info, "Transfer request approved! Booking has been transferred.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You cannot approve this request")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to process transfer request")}
    end
  end

  @impl true
  def handle_event("decline_transfer", %{"message_id" => message_id}, socket) do
    message = Messaging.get_message!(message_id)

    case Messaging.process_booking_transfer_response(message, socket.assigns.current_user, "declined") do
      {:ok, _response_message} ->
        # Refresh messages
        messages = Messaging.get_conversation(socket.assigns.current_user, socket.assigns.other_user)

        {:noreply,
        socket
        |> assign(:messages, messages)
        |> put_flash(:info, "Transfer request declined")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You cannot decline this request")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to process transfer request")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-8 h-screen flex flex-col">
      <!-- Header -->
      <div class="bg-white shadow rounded-lg p-4 mb-4 flex-shrink-0">
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <.link navigate={~p"/messages"} class="text-indigo-600 hover:text-indigo-800 mr-4">
              <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L4.414 9H17a1 1 0 110 2H4.414l5.293 5.293a1 1 0 010 1.414z" clip-rule="evenodd"></path>
              </svg>
            </.link>

            <div>
              <h2 class="text-lg font-semibold text-gray-900">
                <%= OfficeBooking.Accounts.User.full_name(@other_user) %>
              </h2>
              <p class="text-sm text-gray-600">
                <%= @other_user.department || "No department" %> • <%= @other_user.email %>
              </p>
            </div>
          </div>

          <div class="text-right">
            <p class="text-sm text-gray-500">
              <%= length(@messages) %> messages
            </p>
          </div>
        </div>
      </div>

      <!-- Messages Area -->
      <div class="flex-1 bg-white shadow rounded-lg mb-4 flex flex-col min-h-0">
        <!-- Messages List -->
        <div id="messages-container" class="flex-1 overflow-y-auto p-4 space-y-4" phx-hook="ScrollToBottom">
          <%= if @messages != [] do %>
            <div :for={message <- @messages} class="mb-4">
              <%= if OfficeBooking.Messaging.Message.transfer_request?(message) do %>
                <.render_transfer_message message={message} current_user={@current_user} />
              <% else %>
                <div class={[
                  "flex",
                  if(message.from_user_id == @current_user.id, do: "justify-end", else: "justify-start")
                ]}>
                  <div class={[
                    "max-w-xs lg:max-w-md px-4 py-2 rounded-lg",
                    if(message.from_user_id == @current_user.id,
                      do: "bg-indigo-600 text-white",
                      else: "bg-gray-100 text-gray-900")
                  ]}>
                    <!-- Show subject for first message or if different from previous -->
                    <%= if message.subject &&
                          (message == List.first(@messages) ||
                            message.subject != get_previous_message_subject(@messages, message)) do %>
                      <div class={[
                        "text-xs font-medium mb-1",
                        if(message.from_user_id == @current_user.id, do: "text-indigo-100", else: "text-gray-500")
                      ]}>
                        Re: <%= message.subject %>
                      </div>
                    <% end %>

                    <div class="text-sm whitespace-pre-wrap"><%= message.content %></div>

                    <div class={[
                      "text-xs mt-1",
                      if(message.from_user_id == @current_user.id, do: "text-indigo-100", else: "text-gray-500")
                    ]}>
                      <%= format_message_time(message.inserted_at) %>
                      <%= if message.from_user_id == @current_user.id && message.read_at do %>
                        <span class="ml-1">✓</span>
                      <% end %>
                    </div>

                    <!-- Show room/booking context -->
                    <%= if message.room || message.booking do %>
                      <div class={[
                        "text-xs mt-2 pt-2 border-t",
                        if(message.from_user_id == @current_user.id,
                          do: "border-indigo-400 text-indigo-100",
                          else: "border-gray-300 text-gray-500")
                      ]}>
                        <%= if message.booking do %>
                          📅 <%= message.booking.title %>
                        <% else %>
                          🏢 <%= message.room.name %>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-8 text-gray-500">
              <svg class="h-12 w-12 text-gray-400 mx-auto mb-3" fill="currentColor" viewBox="0 0 20 20">
                <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z"></path>
                <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z"></path>
              </svg>
              <p>No messages yet. Start the conversation!</p>
            </div>
          <% end %>
        </div>

        <!-- Message Input -->
        <div class="border-t border-gray-200 p-4 flex-shrink-0">
          <.simple_form for={@form} phx-submit="send_message" phx-change="validate_message" class="flex gap-2">
            <div class="flex-1">
              <.input
                field={@form[:subject]}
                type="text"
                placeholder="Subject (optional)"
                class="mb-2"
              />
              <.input
                field={@form[:content]}
                type="textarea"
                placeholder="Type your message..."
                rows="2"
                class="resize-none"
              />
            </div>

            <div class="flex flex-col justify-end">
              <.button
                phx-disable-with="Sending..."
                class="px-4 py-2 whitespace-nowrap"
                disabled={!get_field(@form.source, :content) || String.trim(get_field(@form.source, :content) || "") == ""}
              >
                Send
              </.button>
            </div>
          </.simple_form>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="bg-white shadow rounded-lg p-4 flex-shrink-0">
        <h3 class="text-sm font-medium text-gray-900 mb-2">Quick Actions</h3>
        <div class="flex space-x-2">
          <.link navigate={~p"/gallery"} class="text-sm text-indigo-600 hover:text-indigo-800">
            Browse Rooms
          </.link>
          <span class="text-gray-300">•</span>
          <.link navigate={~p"/bookings"} class="text-sm text-indigo-600 hover:text-indigo-800">
            My Bookings
          </.link>
          <span class="text-gray-300">•</span>
          <.link
            navigate={~p"/messages/new?user_id=#{@other_user.id}"}
            class="text-sm text-indigo-600 hover:text-indigo-800"
          >
            New Message
          </.link>
        </div>
      </div>
    </div>

    <script>
      // Auto-scroll to bottom when new messages arrive
      window.addEventListener("phx:scroll_to_bottom", () => {
        const container = document.getElementById("messages-container");
        if (container) {
          container.scrollTop = container.scrollHeight;
        }
      });
    </script>
    """
  end

  defp render_transfer_message(assigns) do
    ~H"""
    <div class="bg-yellow-50 border-l-4 border-yellow-400 p-4 rounded-r-lg">
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3 flex-1">
          <h3 class="text-sm font-medium text-yellow-800">Room Transfer Request</h3>

          <!-- Booking Details -->
          <div class="mt-2 text-sm text-yellow-700 bg-yellow-100 p-3 rounded">
            <p><strong>Room:</strong> <%= @message.action_data["room_name"] %></p>
            <p><strong>Time:</strong>
              <%= OfficeBooking.Messaging.Message.format_datetime(@message.action_data["booking_start"]) %> -
              <%= OfficeBooking.Bookings.Booking.format_time(@message.action_data["booking_end"]) %>
            </p>
          </div>

          <!-- User's Message -->
          <div class="mt-3 text-sm text-gray-900">
            <p><%= @message.content %></p>
          </div>

          <!-- Action Buttons (only for recipient and if pending) -->
          <%= if @message.to_user_id == @current_user.id && OfficeBooking.Messaging.Message.pending_action?(@message) do %>
            <div class="mt-4 flex space-x-2">
              <button
                phx-click="approve_transfer"
                phx-value-message_id={@message.id}
                class="px-3 py-1 bg-green-600 text-white text-sm rounded hover:bg-green-700"
              >
                Approve Transfer
              </button>
              <button
                phx-click="decline_transfer"
                phx-value-message_id={@message.id}
                class="px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700"
              >
                Decline
              </button>
            </div>
          <% else %>
            <!-- Status Display -->
            <div class="mt-3">
              <span class={[
                "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                case @message.action_status do
                  "pending" -> "bg-yellow-100 text-yellow-800"
                  "approved" -> "bg-green-100 text-green-800"
                  "declined" -> "bg-red-100 text-red-800"
                  "completed" -> "bg-blue-100 text-blue-800"
                end
              ]}>
                Status: <%= String.capitalize(@message.action_status) %>
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_message_time(datetime) do
    pkt_time = datetime
      |> DateTime.from_naive!("Etc/UTC")  # Convert NaiveDateTime to DateTime first
      |> DateTime.shift_zone!("Asia/Karachi")

    now = DateTime.utc_now() |> DateTime.shift_zone!("Asia/Karachi")

    case Date.diff(DateTime.to_date(now), DateTime.to_date(pkt_time)) do
      0 -> Calendar.strftime(pkt_time, "%I:%M %p")
      1 -> "Yesterday #{Calendar.strftime(pkt_time, "%I:%M %p")}"
      _ -> Calendar.strftime(pkt_time, "%b %d, %I:%M %p")
    end
  end

  defp get_previous_message_subject(messages, current_message) do
    current_index = Enum.find_index(messages, fn msg -> msg.id == current_message.id end)

    if current_index && current_index > 0 do
      Enum.at(messages, current_index - 1).subject
    else
      nil
    end
  end

  defp get_field(changeset, field) do
    Ecto.Changeset.get_field(changeset, field)
  end
end
