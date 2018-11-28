# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Sjc.Repo.insert!(%Sjc.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Sjc.Models.{User, Item, User.Inventory}
alias Sjc.Repo

item =
  %Item{}
  |> Item.changeset(%{amount: 24, multiplier: 1})
  |> Repo.insert!()

# User with Inventory
user =
  %User{}
  |> User.changeset(%{
    email: "some@email.com",
    password: "12345678",
    password_confirmation: "12345678"
  })
  |> Repo.insert!()

inventory =
  %Inventory{}
  |> Inventory.changeset(%{user_id: user.id})
  |> Repo.insert!()

# Update Inventory with the assoc.
inventory
|> Repo.preload(:items)
|> Ecto.Changeset.change()
|> Ecto.Changeset.put_assoc(:items, [item])
|> Repo.update!()
