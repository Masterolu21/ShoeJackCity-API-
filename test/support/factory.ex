defmodule Sjc.Factory do
  @moduledoc """
  Defines factories to use in tests.
  """

  use ExMachina.Ecto, repo: Sjc.Repo

  alias Sjc.Models.User

  def player_factory do
    %{
      id: sequence(:id, &(&1 + 1)),
      health_points: 50,
      shield_points: 0,
      accuracy: sequence(:accuracy, &(&1 + 17)),
      luck: sequence(:luck, &(&1 + 8)),
      inventory: [build(:inventory)]
    }
  end

  def inventory_factory do
    %{
      item_id: sequence(:id, &(&1 + Enum.random(1..10_000))),
      amount: Enum.random(1..99)
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
end
