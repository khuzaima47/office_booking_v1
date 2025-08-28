defmodule OfficeBooking.Repo.Migrations.CreateBookings do
  use Ecto.Migration

  def change do
    create table(:bookings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :room_id, references(:rooms, on_delete: :delete_all), null: false
      add :start_datetime, :utc_datetime, null: false
      add :end_datetime, :utc_datetime, null: false
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "confirmed", null: false

      timestamps()
    end

    create index(:bookings, [:user_id])
    create index(:bookings, [:room_id])
    create index(:bookings, [:room_id, :start_datetime])
    create index(:bookings, [:start_datetime, :end_datetime])
    create index(:bookings, [:status])

    # Prevent overlapping bookings with partial index
    create unique_index(:bookings, [:room_id, :start_datetime, :end_datetime],
           where: "status != 'cancelled'",
           name: :bookings_no_overlap_index)
  end
end
