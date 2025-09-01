defmodule OfficeBookingWeb.BookingLive.New do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.{Rooms, Bookings}
  alias OfficeBooking.Bookings.Booking

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if socket.assigns.current_user do
      room = Rooms.get_room!(room_id)

      # Subscribe to room booking updates
      Bookings.subscribe_to_room_bookings(room_id)

      socket =
        socket
        |> assign(:room, room)
        |> assign(:page_title, "Book #{room.name}")
        |> assign(:selected_date, Date.utc_today())
        |> assign(:available_slots, [])
        |> assign(:conflicting_bookings, [])
        |> assign(:current_booking, nil)
        |> assign(:upcoming_bookings, [])
        |> load_room_availability()
        |> assign_form()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("change_date", params, socket) do
    IO.inspect(params, label: "CHANGE_DATE_PARAMS")

    date_str = params["date"]

    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        IO.inspect({:parsed_date, date}, label: "PARSED_DATE")

        socket =
          socket
          |> assign(:selected_date, date)
          |> load_room_availability()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid date selected")}
    end
  end

  @impl true
  def handle_event("select_slot", %{"start" => start_str, "end" => end_str}, socket) do
    # Parse the ISO8601 strings with better error handling
    with {:ok, start_dt} <- parse_datetime_safe(start_str),
        {:ok, end_dt} <- parse_datetime_safe(end_str) do

      changeset = Booking.changeset(%Booking{}, %{
        room_id: socket.assigns.room.id,
        user_id: socket.assigns.current_user.id,
        start_datetime: start_dt,
        end_datetime: end_dt,
        title: ""
      })

      socket =
        socket
        |> assign(:selected_start, start_dt)
        |> assign(:selected_end, end_dt)
        |> assign_form(changeset)

      {:noreply, socket}
    else
      {:error, reason} ->
        IO.inspect({:datetime_parse_error, start_str, end_str, reason}, label: "DateTime Parse Error")
        {:noreply, put_flash(socket, :error, "Invalid time slot selected")}
    end
  end

# Add this helper function to handle datetime parsing more robustly
  defp parse_datetime_safe(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime} ->
        {:ok, datetime}
      {:ok, datetime, _offset} ->
        # Handle 3-tuple response when timezone offset is present
        {:ok, datetime}
      {:error, :missing_offset} ->
        # Try parsing as naive datetime and assume it's already in the correct timezone
        case NaiveDateTime.from_iso8601(datetime_string) do
          {:ok, naive_dt} ->
            # Convert to UTC assuming the naive datetime is in CET
            case DateTime.new(naive_dt, "Asia/Karachi") do
              {:ok, cet_datetime} ->
                {:ok, DateTime.shift_zone!(cet_datetime, "Etc/UTC")}
              error -> error
            end
          error -> error
        end
      {:error, :invalid_format} ->
        # Try removing any timezone suffix and parsing as naive datetime
        cleaned = datetime_string |> String.replace(~r/[+-]\d{2}:\d{2}$/, "")
        case NaiveDateTime.from_iso8601(cleaned) do
          {:ok, naive_dt} ->
            case DateTime.new(naive_dt, "Asia/Karachi") do
              {:ok, cet_datetime} ->
                {:ok, DateTime.shift_zone!(cet_datetime, "Etc/UTC")}
              error -> error
            end
          error -> error
        end
      error -> error
    end
  end

  @impl true
  def handle_event("validate", %{"booking" => booking_params}, socket) do
    changeset =
      %Booking{}
      |> Booking.changeset(booking_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"booking" => booking_params}, socket) do
    booking_params = Map.merge(booking_params, %{
      "room_id" => socket.assigns.room.id,
      "user_id" => socket.assigns.current_user.id,
      "start_datetime" => socket.assigns[:selected_start],
      "end_datetime" => socket.assigns[:selected_end]
    })

    case Bookings.create_booking(booking_params) do
      {:ok, booking} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room booked successfully!")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("check_conflicts", _params, socket) do
    start_dt = socket.assigns[:selected_start]
    end_dt = socket.assigns[:selected_end]

    if start_dt && end_dt do
      conflicts = Bookings.get_conflicting_bookings(socket.assigns.room, start_dt, end_dt)
      {:noreply, assign(socket, :conflicting_bookings, conflicts)}
    else
      {:noreply, socket}
    end
  end

  # Handle real-time booking updates
  @impl true
  def handle_info({action, _booking}, socket) when action in [:created, :updated, :deleted] do
    socket = load_room_availability(socket)
    {:noreply, socket}
  end

  defp load_room_availability(socket) do
    room = socket.assigns.room
    date = socket.assigns.selected_date

    # Add debug here to see if this function is being called
    IO.inspect({:loading_availability_for_date, date}, label: "Loading Availability")

    available_slots = Bookings.available_time_slots(room, date)
    current_booking = Bookings.get_current_booking(room)
    upcoming_bookings = Bookings.get_upcoming_bookings(room)

    socket
    |> assign(:available_slots, available_slots)
    |> assign(:current_booking, current_booking)
    |> assign(:upcoming_bookings, upcoming_bookings)
  end

  defp assign_form(socket, changeset \\ nil) do
    changeset = changeset || Booking.changeset(%Booking{}, %{})
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <.link navigate={~p"/gallery/#{@room.id}"} class="text-indigo-600 hover:text-indigo-800 mb-4 inline-flex items-center">
          <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L4.414 9H17a1 1 0 110 2H4.414l5.293 5.293a1 1 0 010 1.414z" clip-rule="evenodd"></path>
          </svg>
          Back to Room Details
        </.link>

        <h1 class="text-3xl font-bold text-gray-900">Book <%= @room.name %></h1>
        <p class="text-lg text-gray-600 mt-2">
          <%= @room.location %> • Up to <%= @room.capacity %> people
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Date Selection and Time Slots -->
        <div class="lg:col-span-2">
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4">Select Date & Time</h2>

            <!-- Date Picker -->
            <div class="mb-6">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Select Date
              </label>
              <form phx-change="change_date">
                <input
                  type="date"
                  name="date"
                  value={@selected_date}
                  min={Date.utc_today()}
                  max={Date.add(Date.utc_today(), 2)}
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                />
              </form>
              <p class="text-xs text-gray-500 mt-1">
                Bookings can be made up to 2 days in advance
              </p>
            </div>

            <!-- Available Time Slots -->
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Available Time Slots</h3>

              <%= if @available_slots != [] do %>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
                  <button
                    :for={{start_dt, end_dt} <- @available_slots}
                    phx-click="select_slot"
                    phx-value-start={DateTime.to_iso8601(start_dt)}
                    phx-value-end={DateTime.to_iso8601(end_dt)}
                    class="p-3 border border-gray-200 rounded-lg hover:border-indigo-500 hover:bg-indigo-50 transition-colors text-center"
                  >
                    <div class="text-sm font-medium">
                      <%= Booking.format_time(start_dt) %> - <%= Booking.format_time(end_dt) %>
                    </div>
                    <div class="text-xs text-gray-500">
                      <%= DateTime.diff(end_dt, start_dt, :minute) %> min
                    </div>
                  </button>
                </div>
              <% else %>
                <div class="text-center py-8 text-gray-500">
                  <svg class="h-12 w-12 text-gray-400 mx-auto mb-3" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
                  </svg>
                  <p>No available slots for this date</p>
                  <p class="text-xs">Try selecting a different date</p>
                </div>
              <% end %>
            </div>

            <!-- Booking Form -->
            <%= if assigns[:selected_start] && assigns[:selected_end] do %>
              <div class="border-t pt-6">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Booking Details</h3>

                <div class="bg-indigo-50 p-4 rounded-lg mb-4">
                  <div class="flex items-center">
                    <svg class="h-5 w-5 text-indigo-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"></path>
                    </svg>
                    <span class="text-sm font-medium text-indigo-900">
                      Selected: <%= Booking.format_time(@selected_start) %> - <%= Booking.format_time(@selected_end) %>
                      (<%= DateTime.diff(@selected_end, @selected_start, :minute) %> minutes)
                    </span>
                  </div>
                </div>

                <.simple_form for={@form} phx-submit="save" phx-change="validate">
                  <.input field={@form[:title]} type="text" label="Booking Title"
                           placeholder="e.g., Team Meeting, Client Presentation" />
                  <.input field={@form[:description]} type="textarea" label="Description (optional)"
                           placeholder="Meeting agenda, special requirements, etc." />

                  <:actions>
                    <.button phx-disable-with="Creating booking..." class="w-full">
                      Confirm Booking
                    </.button>
                  </:actions>
                </.simple_form>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Room Info and Current Status -->
        <div class="space-y-6">
          <!-- Room Info Card -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">Room Information</h3>

            <%= if primary_photo = OfficeBooking.Rooms.Room.primary_photo(@room) do %>
              <img
                src={OfficeBooking.Rooms.RoomPhoto.web_path(primary_photo)}
                alt={@room.name}
                class="w-full h-32 object-cover rounded-lg mb-4"
              />
            <% end %>

            <dl class="space-y-2">
              <div class="flex justify-between">
                <dt class="text-sm text-gray-500">Capacity:</dt>
                <dd class="text-sm font-medium"><%= @room.capacity %> people</dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-sm text-gray-500">Location:</dt>
                <dd class="text-sm font-medium"><%= @room.location %></dd>
              </div>
            </dl>

            <%= if @room.features != [] do %>
              <div class="mt-4">
                <h4 class="text-sm font-medium text-gray-900 mb-2">Features</h4>
                <div class="flex flex-wrap gap-1">
                  <span
                    :for={feature <- OfficeBooking.Rooms.Room.feature_names(@room)}
                    class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded"
                  >
                    <%= feature %>
                  </span>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Current Status -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">Current Status</h3>

            <%= if @current_booking do %>
              <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
                <div class="flex items-center mb-2">
                  <svg class="h-5 w-5 text-red-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
                  </svg>
                  <span class="text-sm font-medium text-red-800">Currently Occupied</span>
                </div>
                <div class="text-sm text-red-700">
                  <p class="font-medium"><%= @current_booking.title %></p>
                  <p>By: <%= OfficeBooking.Accounts.User.full_name(@current_booking.user) %></p>
                  <p>Until: <%= Booking.format_time(@current_booking.end_datetime) %></p>
                </div>
              </div>
            <% else %>
              <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                <div class="flex items-center">
                  <svg class="h-5 w-5 text-green-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                  </svg>
                  <span class="text-sm font-medium text-green-800">Currently Available</span>
                </div>
              </div>
            <% end %>

            <!-- Upcoming Bookings -->
            <%= if @upcoming_bookings != [] do %>
              <div>
                <h4 class="text-sm font-medium text-gray-900 mb-2">Upcoming Bookings</h4>
                <div class="space-y-2">
                  <div
                    :for={booking <- Enum.take(@upcoming_bookings, 3)}
                    class="bg-yellow-50 border border-yellow-200 rounded p-3"
                  >
                    <div class="text-sm">
                      <p class="font-medium text-yellow-900"><%= booking.title %></p>
                      <p class="text-yellow-700">
                        <%= Booking.format_time(booking.start_datetime) %> -
                        <%= Booking.format_time(booking.end_datetime) %>
                      </p>
                      <p class="text-yellow-600">
                        By: <%= OfficeBooking.Accounts.User.full_name(booking.user) %>
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Contact Current User (if occupied) -->
          <%= if @current_booking do %>
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-semibold mb-4">Need this room now?</h3>
              <p class="text-sm text-gray-600 mb-4">
                Contact the current user to discuss early checkout or room sharing.
              </p>
              <.link
                navigate={~p"/messages/new?user_id=#{@current_booking.user.id}&room_id=#{@room.id}"}
                class="inline-flex items-center px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 text-sm font-medium"
              >
                <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z"></path>
                  <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z"></path>
                </svg>
                Contact <%= @current_booking.user.first_name %>
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
