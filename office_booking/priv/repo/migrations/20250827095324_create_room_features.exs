defmodule OfficeBooking.Repo.Migrations.CreateRoomFeatures do
  use Ecto.Migration

  def change do
    create table(:room_features) do
      add :room_id, references(:rooms, on_delete: :delete_all), null: false
      add :feature_name, :string, null: false
      add :description, :text

      timestamps()
    end

    create index(:room_features, [:room_id])
    create unique_index(:room_features, [:room_id, :feature_name])
  end
end
