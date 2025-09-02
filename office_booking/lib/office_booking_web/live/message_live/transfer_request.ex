defmodule OfficeBookingWeb.MessageLive.TransferRequest do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.{Messaging, Bookings}

  @impl true
  def mount(%{"booking_id" => booking_id}, _session, socket) do
    if socket.assigns.current_user do
      booking = Bookings.get_booking!(booking_id)

      # Check if user can request transfer (not their own booking)
      if booking.user_id == socket.assigns.current_user.id do
        {:ok,
         socket
         |> put_flash(:error, "You cannot request transfer of your own booking")
         |> push_navigate(to: ~p"/gallery/#{booking.room_id}")}
      else
        socket =
          socket
          |> assign(:page_title, "Request Room Transfer")
          |> assign(:booking, booking)
          |> assign(:content, "")
          |> assign(:errors, [])

        {:ok, socket}
      end
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("validate", %{"content" => content}, socket) do
    errors = if String.trim(content) == "", do: ["Message cannot be empty"], else: []

    socket =
      socket
      |> assign(:content, content)
      |> assign(:errors, errors)

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_request", %{"content" => content}, socket) do
    if String.trim(content) == "" do
      {:noreply, assign(socket, :errors, ["Message cannot be empty"])}
    else
      case Messaging.create_booking_transfer_request(
        socket.assigns.current_user,
        socket.assigns.booking,
        content
      ) do
        {:ok, _message} ->
          {:noreply,
           socket
           |> put_flash(:info, "Transfer request sent successfully!")
           |> push_navigate(to: ~p"/messages")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to send transfer request")
           |> assign(:errors, ["Failed to send request. Please try again."])}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-8">
      <.header>
        Request Room Transfer
        <:subtitle>
          Ask the current user to transfer their booking to you
        </:subtitle>
        <:actions>
          <.link navigate={~p"/gallery/#{@booking.room_id}"}>
            <.button class="bg-gray-500 hover:bg-gray-600">Back to Room</.button>
          </.link>
        </:actions>
      </.header>

      <!-- Booking Information -->
      <div class="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="flex items-center">
          <svg class="h-5 w-5 text-blue-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
          </svg>
          <div class="text-sm text-blue-800">
            <p class="font-medium">Requesting Transfer For:</p>
            <p><%= @booking.title %></p>
            <p>Room: <%= @booking.room.name %></p>
            <p>Time: <%= OfficeBooking.Bookings.Booking.format_datetime(@booking.start_datetime) %> -
               <%= OfficeBooking.Bookings.Booking.format_time(@booking.end_datetime) %></p>
            <p>Current Owner: <%= OfficeBooking.Accounts.User.full_name(@booking.user) %></p>
          </div>
        </div>
      </div>

      <!-- Transfer Request Form -->
      <div class="mt-8 bg-white shadow rounded-lg p-6">
        <form phx-submit="send_request" phx-change="validate">
          <div class="mb-4">
            <label for="content" class="block text-sm font-medium text-gray-700 mb-2">
              Your Message
            </label>
            <textarea
              id="content"
              name="content"
              value={@content}
              rows="6"
              placeholder="Explain why you need this room and ask politely for the transfer..."
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            ></textarea>
          </div>

          <%= if @errors != [] do %>
            <div class="mb-4 bg-red-50 border border-red-200 rounded p-3">
              <%= for error <- @errors do %>
                <p class="text-sm text-red-600"><%= error %></p>
              <% end %>
            </div>
          <% end %>

          <div class="flex justify-end space-x-3">
            <.link
              navigate={~p"/gallery/#{@booking.room_id}"}
              class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              Send Transfer Request
            </button>
          </div>
        </form>
      </div>

      <!-- Help Text -->
      <div class="mt-6 bg-gray-50 rounded-lg p-4">
        <h3 class="text-sm font-medium text-gray-900 mb-2">How This Works</h3>
        <ul class="text-sm text-gray-600 space-y-1">
          <li>• Your request will be sent as a message to the current booking owner</li>
          <li>• They can approve or decline your request from their messages</li>
          <li>• If approved, the booking will be automatically transferred to you</li>
          <li>• You'll receive a notification once they respond</li>
        </ul>
      </div>
    </div>
    """
  end
end
