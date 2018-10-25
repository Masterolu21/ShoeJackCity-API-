defmodule Sjc.Factory do
  @moduledoc """
  Defines factories to use in tests.
  """

  use ExMachina

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
end
