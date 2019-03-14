defmodule Sjc.Game.Player do
  @moduledoc """
  Module that provides a player struct for player stats.
  """

  @enforce_keys [:id]
  defstruct id: 0,
            health_points: 2_000,
            shield_points: 0,
            accuracy: 0,
            luck: 0,
            inventory: []
end
