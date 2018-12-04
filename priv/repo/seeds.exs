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

alias Sjc.Models.{User, Item, User.Inventory, InventoryItems}
alias Sjc.Repo

item =
  Enum.each(1..100, fn num ->
    %Item{}
    |> Item.changeset(%{amount: num * 2, multiplier: num * 3})
    |> Repo.insert!()
  end)

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

Enum.each(1..10, fn num ->
  %InventoryItems{}
  |> InventoryItems.changeset(%{item_id: num, inventory_id: inventory.id})
  |> Repo.insert!()
end)
