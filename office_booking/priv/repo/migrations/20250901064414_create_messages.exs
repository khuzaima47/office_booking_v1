defmodule OfficeBooking.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :from_user_id, references(:users, on_delete: :delete_all), null: false
      add :to_user_id, references(:users, on_delete: :delete_all), null: false
      add :room_id, references(:rooms, on_delete: :nilify_all)
      add :booking_id, references(:bookings, on_delete: :nilify_all)
      add :subject, :string, null: false
      add :content, :text, null: false
      add :read_at, :utc_datetime

      timestamps()
    end

    create index(:messages, [:from_user_id])
    create index(:messages, [:to_user_id])
    create index(:messages, [:room_id])
    create index(:messages, [:booking_id])
    create index(:messages, [:to_user_id, :read_at])
    create index(:messages, [:inserted_at])
  end
end
