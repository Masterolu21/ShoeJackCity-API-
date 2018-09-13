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
      luck: sequence(:luck, &(&1 + 8))
    }
  end
end
