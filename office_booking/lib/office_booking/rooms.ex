defmodule OfficeBooking.Rooms do
  @moduledoc """
  The Rooms context.
  """

  import Ecto.Query, warn: false
  alias OfficeBooking.Repo

  alias OfficeBooking.Rooms.Room
  alias OfficeBooking.Rooms.RoomFeature
  alias OfficeBooking.Rooms.RoomPhoto
  require Logger

  @doc """
  Returns the list of rooms with optional filters.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

      iex> list_rooms(%{"query" => "meeting", "capacity" => "10"})
      [%Room{}, ...]

  """
  def list_rooms(params \\ %{}) do
    Room
    |> where([r], r.is_active == true)
    |> search_by_query(params["query"])
    |> filter_by_capacity(params["capacity"])
    |> preload([:features, :photos])
    |> Repo.all()
  end

  @doc """
  Searches rooms by name or location (used in query pipeline).
  """
  def search_by_query(query, search_term) when is_binary(search_term) and search_term != "" do
    wildcard_search = "%#{search_term}%"

    from r in query,
      where: ilike(r.name, ^wildcard_search) or
            ilike(r.location, ^wildcard_search) or
            ilike(r.description, ^wildcard_search)
  end
  def search_by_query(query, _), do: query

  @doc """
  Filters rooms by capacity (used in query pipeline).
  """
  def filter_by_capacity(query, capacity) when is_binary(capacity) and capacity != "" do
    {min_capacity, _} = Integer.parse(capacity)
    from r in query, where: r.capacity >= ^min_capacity
  end
  def filter_by_capacity(query, _), do: query

  @doc """
  Returns the list of all rooms (admin only).
  """
  def list_all_rooms do
    Room
    |> preload([:features, :photos])
    |> Repo.all()
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(123)
      %Room{}

      iex> get_room!(456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(id) do
    Room
    |> preload([:features, :photos])
    |> Repo.get!(id)
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{field: value})
      {:ok, %Room{}}

      iex> create_room(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end


  @doc """
  Creates a room with features.
  """
  def create_room_with_features(attrs \\ %{}) do

    changeset =
      %Room{}
      |> Room.changeset_for_save(attrs)

    result = Repo.insert(changeset)
    Logger.debug("Insert result: #{inspect(result)}")

    result
  end


  @doc """
  Updates a room.

  ## Examples

      iex> update_room(room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a room with features.
  """
  def update_room_with_features(%Room{} = room, attrs) do

    preloaded_room = room |> Repo.preload(:features)

    changeset =
      preloaded_room
      |> Room.changeset_for_save(attrs)

    result = Repo.update(changeset)
    Logger.debug("Update result: #{inspect(result)}")

    result
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes with features.
  """
  def change_room_with_features(%Room{} = room, attrs \\ %{}) do
    room
    |> Repo.preload(:features)
    |> Room.changeset_with_features(attrs)
  end

  @doc """
  Creates a room feature.
  """
  def create_room_feature(attrs \\ %{}) do
    %RoomFeature{}
    |> RoomFeature.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a room feature.
  """
  def delete_room_feature(%RoomFeature{} = room_feature) do
    Repo.delete(room_feature)
  end


  # Room Photo functions

  # Room Photo functions
  @doc """
  Creates a room photo record and handles file upload.
  """
  def create_room_photo(%Room{} = room, upload) do
    with {:ok, filename} <- save_upload(upload),
         {:ok, room_photo} <- create_photo_record(room, upload, filename) do
      {:ok, room_photo}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a room photo and removes file.
  """
  def delete_room_photo(%RoomPhoto{} = room_photo) do
    # Delete file first
    case File.rm(RoomPhoto.file_path(room_photo)) do
      :ok -> Repo.delete(room_photo)
      {:error, :enoent} -> Repo.delete(room_photo) # File doesn't exist, delete record
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Sets a photo as primary and unsets others for the room.
  """
  def set_primary_photo(%RoomPhoto{} = room_photo) do
    Repo.transaction(fn ->
      # Unset all primary photos for this room
      from(p in RoomPhoto, where: p.room_id == ^room_photo.room_id)
      |> Repo.update_all(set: [is_primary: false])

      # Set this photo as primary
      room_photo
      |> RoomPhoto.changeset(%{is_primary: true})
      |> Repo.update()
      |> case do
        {:ok, photo} -> photo
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # Private helper functions
  defp save_upload(upload) do
    # Ensure upload directory exists
    upload_dir = Path.join([Application.app_dir(:office_booking, "priv/static"), "uploads", "rooms"])
    File.mkdir_p!(upload_dir)

    # Generate unique filename
    extension = Path.extname(upload.client_name)
    filename = "#{Ecto.UUID.generate()}#{extension}"
    destination = Path.join(upload_dir, filename)

    # Copy uploaded file
    case File.cp(upload.path, destination) do
      :ok -> {:ok, filename}
      {:error, reason} -> {:error, "Failed to save file: #{reason}"}
    end
  end

  defp create_photo_record(%Room{} = room, upload, filename) do
    attrs = %{
      room_id: room.id,
      filename: filename,
      original_name: upload.client_name,
      content_type: upload.client_type,
      file_size: File.stat!(upload.path).size,
      is_primary: false
    }

    %RoomPhoto{}
    |> RoomPhoto.changeset(attrs)
    |> Repo.insert()
  end

end
