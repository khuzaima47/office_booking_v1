defmodule OfficeBooking.Repo.Migrations.AddActionFieldsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :action_type, :string
      add :action_data, :map
      add :action_status, :string, default: "pending"
    end

    create index(:messages, [:action_type])
    create index(:messages, [:action_status])
  end
end
