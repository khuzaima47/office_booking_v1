defmodule OfficeBookingWeb.RoomLive.Show do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.Rooms

  @impl true
  def mount(_params, _session, socket) do
    # Check admin access
    if socket.assigns.current_user && OfficeBooking.Accounts.admin?(socket.assigns.current_user) do
      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end


 @impl true
  def handle_params(%{"id" => id}, _, socket) do
    room = Rooms.get_room!(id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:room, room)}
  end

  @impl true
  def handle_info({OfficeBookingWeb.RoomLive.FormComponent, {:saved, room}}, socket) do
    {:noreply, assign(socket, :room, room)}
  end

  @impl true
  def handle_event("delete_photo", %{"photo-id" => photo_id}, socket) do
    photo = Enum.find(socket.assigns.room.photos, &(&1.id == String.to_integer(photo_id)))
    {:ok, _} = Rooms.delete_room_photo(photo)

    updated_room = Rooms.get_room!(socket.assigns.room.id)
    {:noreply, assign(socket, :room, updated_room)}
  end

  @impl true
  def handle_event("set_primary_photo", %{"photo-id" => photo_id}, socket) do
    photo = Enum.find(socket.assigns.room.photos, &(&1.id == String.to_integer(photo_id)))
    {:ok, _} = Rooms.set_primary_photo(photo)

    updated_room = Rooms.get_room!(socket.assigns.room.id)
    {:noreply, assign(socket, :room, updated_room)}
  end

  defp page_title(:show), do: "Show Room"
  defp page_title(:edit), do: "Edit Room"
end
