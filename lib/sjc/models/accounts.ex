defmodule Sjc.Models.Accounts do
  @moduledoc """
  Module that provides convenient functions to work with the models.
  """

  alias Sjc.Repo
  alias Sjc.Models.{User, Item, User.Inventory}

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
end
