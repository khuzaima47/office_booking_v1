defmodule OfficeBooking.Rooms.RoomPhoto do
  use Ecto.Schema
  import Ecto.Changeset

  schema "room_photos" do
    field :filename, :string
    field :original_name, :string
    field :content_type, :string
    field :file_size, :integer
    field :is_primary, :boolean, default: false

    belongs_to :room, OfficeBooking.Rooms.Room

    timestamps()
  end

  @doc false
  def changeset(room_photo, attrs) do
    room_photo
    |> cast(attrs, [:filename, :original_name, :content_type, :file_size, :is_primary, :room_id])
    |> validate_required([:filename, :original_name, :content_type, :file_size, :room_id])
    |> validate_inclusion(:content_type, ["image/jpeg", "image/png", "image/webp"])
    |> validate_number(:file_size, greater_than: 0, less_than: 10_000_000) # 10MB limit
  end

  @doc """
  Returns the full path to the photo file
  """
  def file_path(%__MODULE__{filename: filename}) do
    Path.join([Application.app_dir(:office_booking, "priv/static"), "uploads", "rooms", filename])
  end

  @doc """
  Returns the web path to the photo
  """
  def web_path(%__MODULE__{filename: filename}) do
    "/uploads/rooms/#{filename}"
  end
end
