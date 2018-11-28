defmodule Sjc.Repo.Migrations.CreateInventoryTable do
  use Ecto.Migration

  def change do
    create table(:inventories) do
      add(:user_id, references(:users))

      timestamps()
    end
  end
end
