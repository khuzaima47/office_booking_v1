defmodule OfficeBooking.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  alias OfficeBooking.Rooms.RoomFeature
  alias OfficeBooking.Rooms.RoomPhoto
  alias OfficeBooking.Bookings.Booking
  require Logger

  schema "rooms" do
    field :name, :string
    field :description, :string
    field :location, :string
    field :capacity, :integer
    field :is_active, :boolean, default: false

    has_many :features, RoomFeature, on_delete: :delete_all
    has_many :photos, RoomPhoto, on_delete: :delete_all
    has_many :bookings, Booking, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
      |> cast(attrs, [:name, :description, :capacity, :location, :is_active])
      |> validate_required([:name, :capacity, :location])
      |> validate_length(:name, min: 1, max: 100)
      |> validate_length(:location, min: 1, max: 200)
      |> validate_length(:description, max: 1000)
      |> validate_number(:capacity, greater_than: 0, less_than: 100)
      |> unique_constraint(:name)

  end

  @doc """
  Changeset for creating room with features
  """
  def changeset_with_features(room, attrs) do

    # Handle features association - convert map format to list format
    processed_attrs = case Map.get(attrs, "features") do
      features_map when is_map(features_map) ->
        Logger.debug("Features attrs (map): #{inspect(features_map)}")

        # Convert features map to list format expected by cast_assoc
        # Don't filter out empty features here - let them show in the form
        features_list =
          features_map
          |> Enum.map(fn {_key, feature_attrs} ->
            Logger.debug("Processing feature attrs: #{inspect(feature_attrs)}")
            feature_attrs
          end)

        Logger.debug("Features list after processing: #{inspect(features_list)}")
        Map.put(attrs, "features", features_list)

      features_list when is_list(features_list) ->
        Logger.debug("Features attrs (list): #{inspect(features_list)}")
        attrs

      _ ->
        Logger.debug("No features or invalid format")
        attrs
    end

    Logger.debug("Processed attrs: #{inspect(processed_attrs)}")

    # Apply changeset with features
    final_changeset =
      room
      |> changeset(processed_attrs)
      |> cast_assoc(:features, with: &RoomFeature.changeset/2)
    Logger.debug("Final changeset errors: #{inspect(final_changeset.errors)}")
    Logger.debug("Final changeset changes: #{inspect(final_changeset.changes)}")

    final_changeset
  end

   @doc """
  Changeset for saving room with features (filters out empty features)
  """
  def changeset_for_save(room, attrs) do

    # Handle features association - filter out empty features for save
    processed_attrs = case Map.get(attrs, "features") do
      features_map when is_map(features_map) ->
        Logger.debug("Features attrs (map): #{inspect(features_map)}")

        # Convert features map to list format and filter out empty ones
        features_list =
          features_map
          |> Enum.map(fn {_key, feature_attrs} ->
            Logger.debug("Processing feature attrs: #{inspect(feature_attrs)}")
            feature_attrs
          end)
          |> Enum.reject(fn feature_attrs ->
            # Reject empty features for save
            feature_name = Map.get(feature_attrs, "feature_name", "")
            empty = String.trim(feature_name) == ""
            Logger.debug("Feature empty?: #{empty}, feature_name: '#{feature_name}'")
            empty
          end)

        Logger.debug("Features list after filtering: #{inspect(features_list)}")
        Map.put(attrs, "features", features_list)

      features_list when is_list(features_list) ->
        Logger.debug("Features attrs (list): #{inspect(features_list)}")
        # Filter out empty features from list
        filtered_list = Enum.reject(features_list, fn feature_attrs ->
          feature_name = Map.get(feature_attrs, "feature_name", "")
          String.trim(feature_name) == ""
        end)
        Map.put(attrs, "features", filtered_list)

      _ ->
        Logger.debug("No features or invalid format")
        attrs
    end

    Logger.debug("Processed attrs for save: #{inspect(processed_attrs)}")

    # Apply changeset with features
    final_changeset =
      room
      |> changeset(processed_attrs)
      |> cast_assoc(:features, with: &RoomFeature.changeset/2)
    Logger.debug("Final changeset errors: #{inspect(final_changeset.errors)}")
    Logger.debug("Final changeset changes: #{inspect(final_changeset.changes)}")

    final_changeset
  end



  @doc """
  Returns the primary photo for the room
  """
  def primary_photo(%__MODULE__{photos: photos}) when is_list(photos) do
    Enum.find(photos, fn photo -> photo.is_primary end) || List.first(photos)
  end

  def primary_photo(%__MODULE__{} = room) do
    # If photos aren't preloaded, this will be handled by the context
    room
    |> OfficeBooking.Repo.preload(:photos)
    |> primary_photo()
  end

  @doc """
  Returns all non-primary photos for the room
  """
  def secondary_photos(%__MODULE__{photos: photos}) when is_list(photos) do
    Enum.reject(photos, fn photo -> photo.is_primary end)
  end

  @doc """
  Returns feature names as a list
  """
  def feature_names(%__MODULE__{features: features}) when is_list(features) do
    Enum.map(features, & &1.feature_name)
  end

  def feature_names(%__MODULE__{} = room) do
    room
    |> OfficeBooking.Repo.preload(:features)
    |> feature_names()
  end



  #Bookings Related Functions
  @doc """
  Returns whether the room is currently occupied
  """
  def occupied?(%__MODULE__{} = room) do
    case OfficeBooking.Bookings.get_current_booking(room) do
      nil -> false
      _booking -> true
    end
  end

  @doc """
  Returns the current booking if room is occupied
  """
  def current_booking(%__MODULE__{} = room) do
    OfficeBooking.Bookings.get_current_booking(room)
  end

  @doc """
  Returns upcoming bookings for the room
  """
  def upcoming_bookings(%__MODULE__{} = room) do
    OfficeBooking.Bookings.get_upcoming_bookings(room)
  end

end
