defmodule Sjc.Game.Inventory do
  @moduledoc """
  Structure of the expected user inventory when adding a player.
  """

  @enforce_keys [:item_id, :amount]
  defstruct item_id: 0, amount: 0
end
