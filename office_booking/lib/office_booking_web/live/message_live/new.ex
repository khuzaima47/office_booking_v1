defmodule OfficeBookingWeb.MessageLive.New do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.{Messaging, Accounts, Rooms, Bookings}
  alias OfficeBooking.Messaging.Message

  @impl true
  def mount(params, _session, socket) do
    if socket.assigns.current_user do
      socket =
        socket
        |> assign(:page_title, "Send Message")
        |> assign(:users, list_users())
        |> assign_recipient(params)
        |> assign_room_context(params)
        |> assign_booking_context(params)
        |> assign_form()
        # require IEx; IEx.pry()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  defp assign_recipient(socket, %{"user_id" => user_id}) do
    recipient = Accounts.get_user!(user_id)
    assign(socket, :recipient, recipient)
  end
  defp assign_recipient(socket, _), do: assign(socket, :recipient, nil)

  defp assign_room_context(socket, %{"room_id" => room_id}) do
    room = Rooms.get_room!(room_id)
    assign(socket, :room, room)
  end
  defp assign_room_context(socket, _), do: assign(socket, :room, nil)

  defp assign_booking_context(socket, %{"booking_id" => booking_id}) do
    booking = Bookings.get_booking!(booking_id)
    assign(socket, :booking, booking)
  end
  defp assign_booking_context(socket, _), do: assign(socket, :booking, nil)

  defp assign_form(socket) do
    attrs = build_initial_attrs(socket)
    changeset = Message.changeset(%Message{}, attrs)
    assign(socket, :form, to_form(changeset))
  end

  defp build_initial_attrs(socket) do
    attrs = %{
      "from_user_id" => socket.assigns.current_user.id
    }

    attrs = if socket.assigns[:recipient] do
      Map.put(attrs, "to_user_id", socket.assigns.recipient.id)
    else
      attrs
    end

    attrs = if socket.assigns[:room] do
      attrs
      |> Map.put("room_id", socket.assigns.room.id)
      |> Map.put("subject", Message.room_negotiation_subject(socket.assigns.room))
    else
      attrs
    end

    attrs = if socket.assigns[:booking] do
      booking = OfficeBooking.Repo.preload(socket.assigns.booking, :room)
      attrs
      |> Map.put("booking_id", booking.id)
      |> Map.put("room_id", booking.room_id)
      |> Map.put("subject", Message.booking_negotiation_subject(booking))
    else
      attrs
    end

    attrs
  end

  @impl true
  def handle_event("validate", %{"message" => message_params}, socket) do
    changeset =
      %Message{}
      |> Message.changeset(message_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("send", %{"message" => message_params}, socket) do
    full_params = Map.merge(build_initial_attrs(socket), message_params)

    case Messaging.create_message(full_params) do
      {:ok, _message} ->
        {:noreply,
         socket
         |> put_flash(:info, "Message sent successfully!")
         |> push_navigate(to: ~p"/messages")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp list_users do
    Accounts.list_users()
    |> Enum.map(fn user -> {Accounts.User.full_name(user), user.id} end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-8">
      <.header>
        Send Message
        <:subtitle>
          <%= if @recipient do %>
            To: <%= OfficeBooking.Accounts.User.full_name(@recipient) %>
          <% else %>
            Compose a new message
          <% end %>
        </:subtitle>
        <:actions>
          <.link navigate={~p"/messages"}>
            <.button class="bg-gray-500 hover:bg-gray-600">Back to Messages</.button>
          </.link>
        </:actions>
      </.header>

      <!-- Context Information -->
      <%= if @room || @booking do %>
        <div class="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex items-center">
            <svg class="h-5 w-5 text-blue-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
            </svg>
            <div class="text-sm text-blue-800">
              <%= if @booking do %>
                <p class="font-medium">Regarding Booking: <%= @booking.title %></p>
                <p>Room: <%= @booking.room.name %> • <%= OfficeBooking.Bookings.Booking.format_datetime(@booking.start_datetime) %></p>
              <% else %>
                <p class="font-medium">Regarding Room: <%= @room.name %></p>
                <p><%= @room.location %> • Up to <%= @room.capacity %> people</p>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <div class="mt-8 bg-white shadow rounded-lg p-6">
        <.simple_form for={@form} phx-submit="send" phx-change="validate">
          <%= if is_nil(@recipient) do %>
            <.input
              field={@form[:to_user_id]}
              type="select"
              label="Send to"
              options={@users}
              prompt="Select recipient..."
            />
          <% end %>

          <.input field={@form[:subject]} type="text" label="Subject" />

          <.input
            field={@form[:content]}
            type="textarea"
            label="Message"
            rows="6"
            placeholder="Type your message here..."
          />

          <:actions>
            <.button phx-disable-with="Sending..." class="w-full sm:w-auto">
              Send Message
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end
