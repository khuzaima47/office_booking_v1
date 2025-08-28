defmodule OfficeBookingWeb.RoomLive.Gallery do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.{Rooms, Bookings}
  alias OfficeBooking.Bookings.Booking

  @impl true
  def mount(_params, _session, socket) do
    rooms = Rooms.list_rooms()

    # Subscribe to all room booking updates for live availability
    Enum.each(rooms, fn room ->
      Bookings.subscribe_to_room_bookings(room.id)
    end)

    # Debug: Check if current_user is available
    IO.inspect(socket.assigns[:current_user], label: "Gallery mount - current_user")


    socket =
      socket
      |> assign(:rooms, rooms)
      |> assign(:search_query, "")
      |> assign(:capacity_filter, nil)
      |> assign(:page_title, "Room Gallery")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Room Gallery")
    |> assign(:room, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    room = Rooms.get_room!(id)

    socket
    |> assign(:page_title, "#{room.name}")
    |> assign(:room, room)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    # Real-time search using phx-change
    params = build_filter_params(socket, %{"query" => query})
    rooms = Rooms.list_rooms(params)

    socket =
      socket
      |> assign(:rooms, rooms)
      |> assign(:search_query, query)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    # Handle capacity filter changes
    params = build_filter_params(socket, filter_params)
    rooms = Rooms.list_rooms(params)

    socket =
      socket
      |> assign(:rooms, rooms)
      |> assign(:capacity_filter, filter_params["capacity"])

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    rooms = Rooms.list_rooms(%{})

    socket =
      socket
      |> assign(:rooms, rooms)
      |> assign(:search_query, "")
      |> assign(:capacity_filter, nil)

    {:noreply, socket}
  end

  # Build unified filter parameters
  defp build_filter_params(socket, new_params) do
    %{
      "query" => socket.assigns.search_query,
      "capacity" => socket.assigns.capacity_filter
    }
    |> Map.merge(new_params)
  end

  @impl true
  def handle_info({action, booking}, socket) when action in [:created, :updated, :deleted] do
    # Refresh room data if we're viewing a specific room
    if socket.assigns.room && socket.assigns.room.id == booking.room_id do
      room = Rooms.get_room!(socket.assigns.room.id)
      {:noreply, assign(socket, :room, room)}
    else
      {:noreply, socket}
    end
  end

   @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <%= if @live_action == :index do %>
        <!-- Gallery Index View -->
        <div class="py-8">
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-gray-900">Office Rooms Gallery</h1>
            <p class="mt-2 text-lg text-gray-600">
              Browse available meeting rooms and office spaces
            </p>
          </div>

          <!-- Search and Filters -->
          <div class="mb-8 bg-white p-6 rounded-lg shadow">
            <div class="flex flex-col space-y-4">
              <div class="flex items-center space-x-4 flex-1">
                <!-- Real-time Search -->
                <form phx-change="search" class="flex items-center flex-1">
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search rooms by name or location..."
                    class="w-full px-3 py-2 border rounded-md"
                  />
                </form>

                <!-- Capacity Filter -->
                <form phx-change="filter" class="flex items-center">
                  <select name="filter[capacity]" class="px-3 py-2 border rounded-md">
                    <option value="">Any capacity</option>
                    <option value="2" selected={@capacity_filter == "2"}>2+ people</option>
                    <option value="5" selected={@capacity_filter == "5"}>5+ people</option>
                    <option value="10" selected={@capacity_filter == "10"}>10+ people</option>
                    <option value="20" selected={@capacity_filter == "20"}>20+ people</option>
                  </select>
                </form>

                <!-- Clear Filters -->
                <button phx-click="clear_filters" class="px-4 py-2 bg-gray-300 text-gray-800 rounded hover:bg-gray-400">
                  Clear Filters
                </button>
              </div>
            </div>
          </div>

          <!-- Rooms Grid -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div
              :for={room <- @rooms}
              class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow cursor-pointer"
              phx-click={JS.navigate(~p"/gallery/#{room.id}")}
            >
              <div class="h-48 bg-gray-200">
                <%= if primary_photo = OfficeBooking.Rooms.Room.primary_photo(room) do %>
                  <img
                    src={OfficeBooking.Rooms.RoomPhoto.web_path(primary_photo)}
                    alt={room.name}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center text-gray-400">
                    <.icon name="hero-photo" class="h-16 w-16" />
                  </div>
                <% end %>
              </div>

              <div class="p-4">
                <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= room.name %></h3>
                <p class="text-sm text-gray-600 mb-2">📍 <%= room.location %></p>
                <p class="text-sm text-gray-600 mb-3">👥 Up to <%= room.capacity %> people</p>

                <%= if room.description do %>
                  <p class="text-sm text-gray-700 mb-3 line-clamp-2"><%= room.description %></p>
                <% end %>

                <!-- Features -->
                <div class="flex flex-wrap gap-1">
                  <span
                    :for={feature <- Enum.take(OfficeBooking.Rooms.Room.feature_names(room), 3)}
                    class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded"
                  >
                    <%= feature %>
                  </span>
                  <%= if length(OfficeBooking.Rooms.Room.feature_names(room)) > 3 do %>
                    <span class="inline-block bg-gray-100 text-gray-600 text-xs px-2 py-1 rounded">
                      +<%= length(OfficeBooking.Rooms.Room.feature_names(room)) - 3 %> more
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%= if @rooms == [] do %>
            <div class="text-center py-12">
              <.icon name="hero-magnifying-glass" class="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 class="text-lg font-medium text-gray-900 mb-2">No rooms found</h3>
              <p class="text-gray-500">Try adjusting your search or filters.</p>
            </div>
          <% end %>
        </div>

      <% else %>
        <!-- Individual Room View -->
        <div class="py-8">
          <div class="mb-6">
            <.link navigate={~p"/gallery"} class="text-blue-600 hover:text-blue-800 mb-4 inline-flex items-center">
              <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" />
              Back to Gallery
            </.link>

            <h1 class="text-3xl font-bold text-gray-900"><%= @room.name %></h1>
            <p class="text-lg text-gray-600 mt-2">📍 <%= @room.location %> • 👥 Up to <%= @room.capacity %> people</p>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Photo Gallery -->
            <div>
              <div class="mb-4">
                <%= if primary_photo = OfficeBooking.Rooms.Room.primary_photo(@room) do %>
                  <img
                    src={OfficeBooking.Rooms.RoomPhoto.web_path(primary_photo)}
                    alt={@room.name}
                    class="w-full h-64 object-cover rounded-lg shadow-md"
                  />
                <% else %>
                  <div class="w-full h-64 bg-gray-200 rounded-lg shadow-md flex items-center justify-center">
                    <.icon name="hero-photo" class="h-16 w-16 text-gray-400" />
                  </div>
                <% end %>
              </div>

              <!-- Secondary Photos -->
              <% secondary_photos = OfficeBooking.Rooms.Room.secondary_photos(@room) %>
              <%= if secondary_photos != [] do %>
                <div class="grid grid-cols-3 gap-2">
                  <img
                    :for={photo <- Enum.take(secondary_photos, 6)}
                    src={OfficeBooking.Rooms.RoomPhoto.web_path(photo)}
                    alt={@room.name}
                    class="w-full h-20 object-cover rounded cursor-pointer hover:opacity-80"
                  />
                </div>
              <% end %>
            </div>

            <!-- Room Details -->
            <div>
              <div class="bg-white p-6 rounded-lg shadow">
                <%= if @room.description do %>
                  <div class="mb-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-2">Description</h3>
                    <p class="text-gray-700"><%= @room.description %></p>
                  </div>
                <% end %>

                <div class="mb-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-3">Features & Amenities</h3>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    <div
                      :for={feature <- @room.features}
                      class="flex items-center p-3 bg-blue-50 rounded-lg"
                    >
                      <.icon name="hero-check-circle" class="h-5 w-5 text-blue-600 mr-2" />
                      <div>
                        <div class="font-medium text-blue-900"><%= feature.feature_name %></div>
                        <%= if feature.description do %>
                          <div class="text-sm text-blue-700"><%= feature.description %></div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Contact Section -->
                <%= if !@current_user do %>
                  <div class="border-t pt-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-3">Interested in this room?</h3>
                    <p class="text-gray-600 mb-4">
                      Sign in to check availability and book this room for your meetings.
                    </p>
                    <.link
                      navigate={~p"/users/log_in"}
                      class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                    >
                      Sign In to Book
                    </.link>
                  </div>
                <% else %>
                  <!-- Quick Book Section for signed-in users -->
                  <div class="border-t pt-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-3">Ready to book?</h3>
                    <p class="text-gray-600 mb-4">
                      Check availability and reserve this room for your meeting.
                    </p>
                    <.link
                      navigate={~p"/rooms/#{@room.id}/book"}
                      class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                    >
                      Book This Room
                    </.link>
                  </div>
                <% end %>
              </div>
            </div>
            <div class="lg:col-span-2 mt-8">
              <div class="bg-white p-6 rounded-lg shadow">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">Room Availability</h3>

                <!-- Current Status -->
                <%= if current_booking = OfficeBooking.Rooms.Room.current_booking(@room) do %>
                  <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
                    <div class="flex items-center justify-between">
                      <div>
                        <p class="text-sm font-medium text-red-800">Currently Occupied</p>
                        <p class="text-sm text-red-700">
                          <%= current_booking.title %> by <%= OfficeBooking.Accounts.User.full_name(current_booking.user) %>
                        </p>
                        <p class="text-sm text-red-600">
                          Until: <%= OfficeBooking.Bookings.Booking.format_time(current_booking.end_datetime) %>
                        </p>
                      </div>

                      <%= if assigns[:current_user] do %>
                        <.link
                          navigate={~p"/messages/new?#{[user_id: current_booking.user.id, room_id: @room.id]}"}
                          class="px-3 py-2 bg-indigo-600 text-white text-sm rounded hover:bg-indigo-700"
                        >
                          Contact User
                        </.link>
                      <% end %>
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
                <% upcoming = OfficeBooking.Rooms.Room.upcoming_bookings(@room) %>
                <%= if upcoming != [] do %>
                  <div class="mb-4">
                    <h4 class="text-md font-medium text-gray-900 mb-2">Upcoming Bookings</h4>
                    <div class="space-y-2">
                      <div
                        :for={booking <- Enum.take(upcoming, 3)}
                        class="bg-yellow-50 border border-yellow-200 rounded p-3 flex items-center justify-between"
                      >
                        <div class="text-sm">
                          <p class="font-medium text-yellow-900"><%= booking.title %></p>
                          <p class="text-yellow-700">
                            <%= OfficeBooking.Bookings.Booking.format_time(booking.start_datetime) %> -
                            <%= OfficeBooking.Bookings.Booking.format_time(booking.end_datetime) %>
                          </p>
                          <p class="text-yellow-600">
                            By: <%= OfficeBooking.Accounts.User.full_name(booking.user) %>
                          </p>
                        </div>

                        <%= if assigns[:current_user] do %>
                          <.link
                            navigate={~p"/messages/new?#{[user_id: booking.user.id, room_id: @room.id]}"}
                            class="px-2 py-1 bg-indigo-600 text-white text-xs rounded hover:bg-indigo-700"
                          >
                            Contact
                          </.link>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>

                <!-- Book This Room Button -->
                <%= if assigns[:current_user] do %>
                  <.link
                    navigate={~p"/rooms/#{@room.id}/book"}
                    class="w-full bg-indigo-600 text-white py-3 px-4 rounded-lg text-center font-medium hover:bg-indigo-700 transition-colors block"
                  >
                    Book This Room
                  </.link>
                <% else %>
                  <div class="text-center p-4 bg-gray-50 rounded-lg">
                    <p class="text-gray-600 mb-2">Sign in to book this room</p>
                    <.link navigate={~p"/users/log_in"} class="text-indigo-600 hover:text-indigo-800 font-medium">
                      Sign In
                    </.link>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
