defmodule OfficeBooking.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :name, :string
      add :description, :text
      add :capacity, :integer
      add :location, :string
      add :is_active, :boolean, default: false, null: false

      timestamps()
    end
    create unique_index(:rooms, [:name])
    create index(:rooms, [:is_active])
  end
end
