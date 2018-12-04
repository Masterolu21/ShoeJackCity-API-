defmodule Sjc.Models.Accounts do
  @moduledoc """
  Module that provides convenient functions to work with the models.
  """

  import Ecto.Query, only: [from: 2]

  alias Sjc.Repo
  alias Sjc.Models.{User, Item, User.Inventory, InventoryItems}

  # User
  def create_user(%User{} = user, params \\ %{}) do
    # This creates an Inventory as well.

    op =
      user
      |> User.changeset(params)
      |> Repo.insert()

    case op do
      {:ok, user} ->
        %Inventory{}
        |> Inventory.changeset(%{user_id: user.id})
        |> Repo.insert()

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user(%User{} = user, changes \\ %{}) do
    user
    |> User.changeset(changes)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  # Inventory
  def update_inventory(%Inventory{} = inventory, changes \\ %{}) do
    inventory
    |> Inventory.changeset(changes)
    |> Repo.update()
  end

  # ITEM
  def create_item(%Item{} = item, params \\ %{}) do
    item
    |> Item.changeset(params)
    |> Repo.insert()
  end

  def update_item(%Item{} = item, changes \\ %{}) do
    item
    |> Item.changeset(changes)
    |> Repo.update()
  end

  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  @doc """
  Updates 'item_id' on 'inventory' adding 'amount' to it.
  """
  def add_inventory_item_amount(inventory_id, item_id, amount) do
    query =
      from(i in InventoryItems,
        where: i.inventory_id == ^inventory_id,
        where: i.item_id == ^item_id,
        preload: [:inventory, :item]
      )

    inventory = Repo.one(query)

    inventory
    |> Ecto.Changeset.change(%{quantity: inventory.quantity + amount})
    |> Repo.update()
  end

  @doc """
  Updates 'item_id' on 'inventory' removing 'amount' from it.
  """
  def remove_inventory_item_amount(inventory_id, item_id, amount) do
    query =
      from(i in InventoryItems,
        where: i.inventory_id == ^inventory_id,
        where: i.item_id == ^item_id,
        preload: [:inventory, :item]
      )

    inventory = Repo.one(query)

    inventory
    |> Ecto.Changeset.change(%{quantity: inventory.quantity - amount})
    |> Repo.update()
  end

  @doc """
  Adds 'item_amount' to 'inventory' of 'item'. Mostly used to add new items to the inventory.
  """
  def add_item_to_inventory(item_id, inventory_id) do
    %InventoryItems{}
    |> InventoryItems.changeset(%{item_id: item_id, inventory_id: inventory_id})
    |> Repo.insert!()
  end
end
