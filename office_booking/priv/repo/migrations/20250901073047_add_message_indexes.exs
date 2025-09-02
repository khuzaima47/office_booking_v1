defmodule OfficeBooking.Repo.Migrations.AddMessageIndexes do
  use Ecto.Migration

  def change do
    # Add composite indexes for better query performance
    create index(:messages, [:from_user_id, :to_user_id])
    create index(:messages, [:to_user_id, :from_user_id])
    create index(:messages, [:room_id, :inserted_at])
    create index(:messages, [:booking_id, :inserted_at])
  end
end
