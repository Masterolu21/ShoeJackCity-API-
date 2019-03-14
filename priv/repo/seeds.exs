alias Sjc.Models.{User, Item, User.Inventory, InventoryItems}
alias Sjc.Repo

priv = :sjc |> :code.priv_dir() |> to_string()
items = (priv <> "/items.json") |> File.read!() |> Jason.decode!()

[items["bombs"], items["shields"], items["heal"]]
|> List.flatten()
|> Enum.each(fn item ->
  %Item{}
  |> Item.changeset(item)
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
