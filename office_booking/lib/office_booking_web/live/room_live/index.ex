defmodule OfficeBookingWeb.RoomLive.Index do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.Rooms
  alias OfficeBooking.Rooms.Room
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Check admin access
    if socket.assigns.current_user && OfficeBooking.Accounts.admin?(socket.assigns.current_user) do
      socket =
        socket
        |> assign(:page_title, "Room Management")
        |> stream(:rooms, list_rooms())

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Room")
    |> assign(:room, Rooms.get_room!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Room")
    |> assign(:room, %Room{features: []})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Rooms")
    |> assign(:room, nil)
  end

  @impl true
  def handle_info({OfficeBookingWeb.RoomLive.FormComponent, {:saved, room}}, socket) do

      {:noreply,
      socket
      |> put_flash(:info, "Room created successfully!")
      |> stream_insert(:rooms, room)
      |> push_navigate(to: ~p"/rooms")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do

    room = Rooms.get_room!(id)
    {:ok, _} = Rooms.delete_room(room)
    {:noreply, stream_delete(socket, :rooms, room)}
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    room = Rooms.get_room!(id)
    {:ok, updated_room} = Rooms.update_room(room, %{is_active: !room.is_active})
    {:noreply, stream_insert(socket, :rooms, updated_room)}
  end

  defp list_rooms do
    Logger.debug("=== LIST_ROOMS ===")
    rooms = Rooms.list_all_rooms()
    Logger.debug("Retrieved #{length(rooms)} rooms")
    rooms
  end

end
