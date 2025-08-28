defmodule OfficeBookingWeb.BookingLive.Index do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.Bookings
  alias OfficeBooking.Bookings.Booking
  alias OfficeBooking.{Bookings, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      user = socket.assigns.current_user

      # Subscribe to user's booking updates
      Bookings.subscribe_to_user_bookings(user.id)

      # Admin users also subscribe to all bookings
      if Accounts.admin?(user) do
        Bookings.subscribe_to_all_bookings()
      end

      socket =
        socket
        |> assign(:page_title, "My Bookings")
        |> assign(:filter, "upcoming")
        |> load_bookings()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end


  @impl true
  def handle_event("filter_bookings", %{"filter" => filter}, socket) do
    socket =
      socket
      |> assign(:filter, filter)
      |> load_bookings()

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_booking", %{"id" => booking_id}, socket) do
    booking = get_user_booking(socket.assigns.current_user, booking_id)

    case Bookings.cancel_booking(booking) do
      {:ok, _booking} ->
        socket =
          socket
          |> put_flash(:info, "Booking cancelled successfully")
          |> load_bookings()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel booking")}
    end
  end

  @impl true
  def handle_event("delete_booking", %{"id" => booking_id}, socket) do
    # Admin only
    if Accounts.admin?(socket.assigns.current_user) do
      booking = Bookings.get_booking!(booking_id)

      case Bookings.delete_booking(booking) do
        {:ok, _booking} ->
          socket =
            socket
            |> put_flash(:info, "Booking deleted successfully")
            |> load_bookings()

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete booking")}
      end
    else
      {:noreply, put_flash(socket, :error, "Access denied")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Booking")
    |> assign(:booking, Bookings.get_booking!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Booking")
    |> assign(:booking, %Booking{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Bookings")
    |> assign(:booking, nil)
  end

  # Handle real-time updates
  @impl true
  def handle_info({action, _booking}, socket) when action in [:created, :updated, :deleted] do
    socket = load_bookings(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({OfficeBookingWeb.BookingLive.FormComponent, {:saved, booking}}, socket) do
    {:noreply, stream_insert(socket, :bookings, booking)}
  end

  defp load_bookings(socket) do
    user = socket.assigns.current_user
    filter = socket.assigns.filter
    is_admin = Accounts.admin?(user)

    bookings = case {filter, is_admin} do
      {"upcoming", _} -> get_upcoming_user_bookings(user)
      {"past", _} -> get_past_user_bookings(user)
      {"all", true} -> Bookings.list_all_bookings()
      {"all", false} -> get_upcoming_user_bookings(user)  # fallback
      {_, _} -> get_upcoming_user_bookings(user)
    end

    assign(socket, :bookings, bookings)
  end

  defp get_upcoming_user_bookings(user) do
    now = DateTime.utc_now()

    user
    |> Bookings.list_user_bookings()
    |> Enum.filter(fn booking ->
      DateTime.compare(booking.end_datetime, now) == :gt
    end)
  end

  defp get_past_user_bookings(user) do
    now = DateTime.utc_now()

    user
    |> Bookings.list_user_bookings()
    |> Enum.filter(fn booking ->
      DateTime.compare(booking.end_datetime, now) != :gt
    end)
    |> Enum.reverse() # Most recent first
  end

  defp get_user_booking(user, booking_id) do
    Bookings.get_user_booking!(user, booking_id)
  end

end
