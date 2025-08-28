defmodule OfficeBookingWeb.UploadHelpers do
  @moduledoc """
  Helpers for file uploads in LiveView
  """

  require Logger

  @doc """
  Validates image uploads
  """
  def validate_image_upload(socket, upload_name, opts \\ []) do
    max_file_size = Keyword.get(opts, :max_file_size, 10_000_000) # 10MB default
    max_entries = Keyword.get(opts, :max_entries, 5)

    Phoenix.LiveView.allow_upload(socket, upload_name,
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: max_entries,
      max_file_size: max_file_size
    )
  end

  @doc """
  Processes uploaded images and creates photo records
  """
  def process_uploaded_images(socket, upload_name, room, rooms_context \\ OfficeBooking.Rooms) do
    {completed_entries, _errors} = Phoenix.LiveView.uploaded_entries(socket, upload_name)
    Logger.debug("Completed entries: #{inspect(completed_entries)}")

    {completed, errors} =
      completed_entries
      |> Enum.reduce({[], []}, fn entry, {completed, errors} ->
        Logger.debug("Processing entry: #{inspect(entry)}")

        result = Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
          upload = %{
            path: path,
            client_name: entry.client_name,
            client_type: entry.client_type
          }

          Logger.debug("Calling create_room_photo with upload: #{inspect(upload)}")
          {:ok, rooms_context.create_room_photo(room, upload)}
        end)

        Logger.debug("Consume result: #{inspect(result)}")

        case result do
          {:ok, photo} ->
            Logger.debug("Photo added: #{inspect(photo)}")
            {[photo | completed], errors}
          {:error, reason} ->
            Logger.debug("Upload error: #{inspect(reason)}")
            {completed, [reason | errors]}
        end
      end)

    Logger.debug("Processed photos: #{inspect(completed)}")
    Logger.debug("Errors: #{inspect(errors)}")

    case errors do
      [] -> {:ok, Enum.reverse(completed)}
      _ -> {:error, errors}
    end
  end
end
