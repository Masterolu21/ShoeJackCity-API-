defmodule Sjc.Repo.Migrations.CreateItemsTable do
  use Ecto.Migration

  def change do
    create table(:items) do
      add(:amount, :integer)
      add(:multiplier, :integer)

      timestamps()
    end
  end
end
