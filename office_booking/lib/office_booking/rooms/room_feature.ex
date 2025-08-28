defmodule OfficeBooking.Rooms.RoomFeature do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  schema "room_features" do
    field :feature_name, :string
    field :description, :string

    belongs_to :room, OfficeBooking.Rooms.Room

    timestamps()
  end

  @doc false
  def changeset(room_feature, attrs) do
    room_feature
      |> cast(attrs, [:feature_name, :description, :room_id])
      |> maybe_validate_required_feature_name()
      |> validate_length(:feature_name, max: 100)
      |> validate_length(:description, max: 500)
      |> unique_constraint([:room_id, :feature_name])
  end

  # Only require feature_name if it's not empty (allows empty features in form)
  defp maybe_validate_required_feature_name(changeset) do
    feature_name = get_change(changeset, :feature_name) || get_field(changeset, :feature_name)

    case feature_name do
      nil -> changeset  # Allow nil for new empty features
      "" -> changeset   # Allow empty string for form display
      _name -> validate_required(changeset, [:feature_name])  # Require if not empty
    end
  end

end
