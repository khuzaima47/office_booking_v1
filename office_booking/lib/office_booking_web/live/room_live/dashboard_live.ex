defmodule OfficeBookingWeb.DashboardLive do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.Bookings
  alias OfficeBooking.Rooms
  alias OfficeBooking.Bookings.Booking
  alias OfficeBooking.{Bookings, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      user = socket.assigns.current_user

      # Subscribe to user's booking updates
      Bookings.subscribe_to_user_bookings(user.id)

      socket =
        socket
        |> assign(:page_title, "Dashboard")
        |> load_dashboard_data()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  # Handle real-time booking updates
  @impl true
  def handle_info({action, _booking}, socket) when action in [:created, :updated, :deleted] do
    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end

  defp load_dashboard_data(socket) do
    user = socket.assigns.current_user
    now = DateTime.utc_now()

    all_bookings = Bookings.list_user_bookings(user)

    upcoming_bookings = Enum.filter(all_bookings, &(DateTime.compare(&1.end_datetime, now) == :gt))
    current_booking = Enum.find(upcoming_bookings, &OfficeBooking.Bookings.Booking.in_progress?/1)
    next_booking = upcoming_bookings |> Enum.reject(&OfficeBooking.Bookings.Booking.in_progress?/1) |> List.first()

    socket
    |> assign(:upcoming_bookings, upcoming_bookings)
    |> assign(:current_booking, current_booking)
    |> assign(:next_booking, next_booking)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <.header>
        Welcome, <%= OfficeBooking.Accounts.User.full_name(@current_user) %>!
        <:subtitle>Your booking dashboard</:subtitle>
      </.header>

      <!-- Quick Status Cards -->
      <div class="mt-8 grid grid-cols-1 md:grid-cols-3 gap-6">
        <!-- Current Booking -->
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-3 flex items-center">
            <svg class="h-5 w-5 text-green-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
            </svg>
            Current Booking
          </h3>
          <%= if @current_booking do %>
            <div class="space-y-2">
              <p class="font-medium text-gray-900"><%= @current_booking.title %></p>
              <p class="text-sm text-gray-600"><%= @current_booking.room.name %></p>
              <p class="text-sm text-gray-500">
                Until <%= OfficeBooking.Bookings.Booking.format_time(@current_booking.end_datetime) %>
              </p>
            </div>
          <% else %>
            <p class="text-gray-600">No active booking</p>
          <% end %>
        </div>

        <!-- Next Booking -->
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-3 flex items-center">
            <svg class="h-5 w-5 text-blue-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"></path>
            </svg>
            Next Booking
          </h3>
          <%= if @next_booking do %>
            <div class="space-y-2">
              <p class="font-medium text-gray-900"><%= @next_booking.title %></p>
              <p class="text-sm text-gray-600"><%= @next_booking.room.name %></p>
              <p class="text-sm text-gray-500">
                <%= OfficeBooking.Bookings.Booking.format_datetime(@next_booking.start_datetime) %>
              </p>
            </div>
          <% else %>
            <p class="text-gray-600">No upcoming bookings</p>
          <% end %>
        </div>

        <!-- Quick Actions -->
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-3 flex items-center">
            <svg class="h-5 w-5 text-purple-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z" clip-rule="evenodd"></path>
            </svg>
            Quick Actions
          </h3>
          <div class="space-y-3">
            <.link navigate={~p"/gallery"} class="block text-indigo-600 hover:text-indigo-800 text-sm">
              Browse Rooms
            </.link>
            <.link navigate={~p"/bookings"} class="block text-indigo-600 hover:text-indigo-800 text-sm">
              My Bookings
            </.link>
            <%= if OfficeBooking.Accounts.admin?(@current_user) do %>
              <.link navigate={~p"/rooms"} class="block text-indigo-600 hover:text-indigo-800 text-sm">
                Manage Rooms
              </.link>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Recent Bookings -->
      <%= if @upcoming_bookings != [] do %>
        <div class="mt-8">
          <div class="bg-white rounded-lg shadow">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-semibold text-gray-900">Upcoming Bookings</h2>
            </div>
            <div class="divide-y divide-gray-200">
              <div
                :for={booking <- Enum.take(@upcoming_bookings, 5)}
                class="px-6 py-4 hover:bg-gray-50"
              >
                <div class="flex items-center justify-between">
                  <div class="flex-1">
                    <div class="flex items-center">
                      <h4 class="text-sm font-medium text-gray-900 mr-2"><%= booking.title %></h4>
                      <span class={[
                        "inline-flex px-2 py-1 text-xs rounded-full font-medium",
                        if(OfficeBooking.Bookings.Booking.in_progress?(booking),
                           do: "bg-green-100 text-green-800",
                           else: "bg-blue-100 text-blue-800")
                      ]}>
                        <%= if OfficeBooking.Bookings.Booking.in_progress?(booking), do: "In Progress", else: "Confirmed" %>
                      </span>
                    </div>

                    <div class="mt-1 flex items-center text-sm text-gray-600">
                      <svg class="h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h8a2 2 0 012 2v12a1 1 0 110 2h-3a1 1 0 01-1-1v-6a1 1 0 00-1-1H9a1 1 0 00-1 1v6a1 1 0 01-1 1H4a1 1 0 110-2V4z" clip-rule="evenodd"></path>
                      </svg>
                      <%= booking.room.name %>

                      <svg class="h-4 w-4 ml-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"></path>
                      </svg>
                      <%= OfficeBooking.Bookings.Booking.format_datetime(booking.start_datetime) %>
                    </div>
                  </div>

                  <div class="flex space-x-2">
                    <.link
                      navigate={~p"/gallery/#{booking.room.id}"}
                      class="text-indigo-600 hover:text-indigo-800 text-sm"
                    >
                      View Room
                    </.link>
                  </div>
                </div>
              </div>
            </div>

            <%= if length(@upcoming_bookings) > 5 do %>
              <div class="px-6 py-3 bg-gray-50 border-t border-gray-200">
                <.link navigate={~p"/bookings"} class="text-sm text-indigo-600 hover:text-indigo-800">
                  View all <%= length(@upcoming_bookings) %> bookings →
                </.link>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
