defmodule OfficeBookingWeb.RoomController do
  use OfficeBookingWeb, :controller

  def show_photo(conn, %{"filename" => filename}) do
    file_path = Path.join([Application.app_dir(:office_booking, "priv/static"), "uploads", "rooms", filename])

    case File.exists?(file_path) do
      true -> send_file(conn, 200, file_path)
      false -> send_resp(conn, 404, "File not found")
    end
  end
end
