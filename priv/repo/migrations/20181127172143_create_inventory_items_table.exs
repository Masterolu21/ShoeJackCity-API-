defmodule Sjc.Repo.Migrations.CreateInventoryItemsTable do
  use Ecto.Migration

  def change do
    create table(:inventory_items) do
      add(:quantity, :integer)
      add(:inventory_id, references(:inventories))
      add(:item_id, references(:items))

      timestamps()
    end
  end
end
