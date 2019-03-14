defmodule Sjc.Repo.Migrations.CreateItemsTable do
  use Ecto.Migration

  def change do
    create table(:items) do
      add(:name, :string)
      add(:damage, :integer)
      add(:reduce, :integer)
      add(:effect, :string)
      add(:chance, :integer)
      add(:mpc, :integer)
      add(:prereq, :string)

      timestamps()
    end
  end
end
