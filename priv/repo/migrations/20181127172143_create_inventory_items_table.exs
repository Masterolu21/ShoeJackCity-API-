defmodule Sjc.Repo.Migrations.CreateInventoryItemsTable do
  use Ecto.Migration

  def change do
    create table(:inventory_items, primary_key: false) do
      add(:inventory_id, references(:inventories))
      add(:item_id, references(:items))
    end
  end
end
