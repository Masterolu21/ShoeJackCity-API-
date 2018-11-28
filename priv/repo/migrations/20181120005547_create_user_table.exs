defmodule Sjc.Repo.Migrations.CreateUserTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string, null: false)
      add(:password_hash, :string)
      add(:points, :integer)

      timestamps()
    end

    create(unique_index(:users, :email))
  end
end
