defmodule Sjc.Factory do
  @moduledoc """
  Defines factories to use in tests.
  """

  use ExMachina.Ecto, repo: Sjc.Repo

  alias Sjc.Models.{User, User.Inventory, Item, InventoryItems}

  def player_factory do
    %{
      id: sequence(:id, &(&1 + 1)),
      health_points: 50,
      inventory: [build(:player_inventory)]
    }
  end

  def player_inventory_factory do
    %{
      name: "item name",
      damage: Enum.random(1..100),
      reduce: Enum.random(1..100),
      effect: "",
      chance: Enum.random(1..100),
      mpc: Enum.random(1..100),
      prereq: ""
    }
  end

  def game_factory do
    name =
      10
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64()
      |> binary_part(0, 10)

    %{
      name: name
    }
  end

  def user_factory do
    %User{
      email: sequence(:email, &"email_#{&1}@gmail.com"),
      password: "some_generic_password",
      password_confirmation: "some_generic_password"
    }
  end

  def inventory_factory do
    %Inventory{
      items: [build(:item)],
      user: build(:user)
    }
  end

  def item_factory do
    %Item{
      name: "item name",
      damage: 20,
      reduce: Enum.random(1..100),
      effect: "",
      chance: Enum.random(1..100),
      mpc: Enum.random(1..100),
      prereq: ""
    }
  end

  def inventory_items_factory do
    %InventoryItems{
      quantity: 20,
      inventory: build(:inventory),
      item: build(:item)
    }
  end
end
