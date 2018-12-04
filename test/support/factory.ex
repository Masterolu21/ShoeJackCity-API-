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
      amount: Enum.random(1..99),
      multiplier: Enum.random(1..5)
    }
  end

  def game_factory do
    %{
      name: sequence(:name, &"game_#{&1}")
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
      amount: Enum.random(1..20),
      multiplier: Enum.random(1..10)
    }
  end

  def inventory_items_factory do
    %InventoryItems{
      quantity: 0,
      inventory: build(:inventory),
      item: build(:item)
    }
  end
end
