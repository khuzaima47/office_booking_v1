defmodule OfficeBooking.Repo.Migrations.CreateRoomPhotos do
  use Ecto.Migration

  def change do
    create table(:room_photos) do
      add :room_id, references(:rooms, on_delete: :delete_all), null: false
      add :filename, :string, null: false
      add :original_name, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :is_primary, :boolean, default: false, null: false

      timestamps()
    end

    create index(:room_photos, [:room_id])
    create index(:room_photos, [:room_id, :is_primary])
  end
end
