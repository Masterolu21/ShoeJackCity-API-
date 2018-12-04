defmodule Sjc.Models.InventoryItems do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Sjc.Models.{User.Inventory, Item}

  # @primary_key false
  schema "inventory_items" do
    field(:quantity, :integer, default: 0)

    belongs_to(:inventory, Inventory)
    belongs_to(:item, Item)

    timestamps()
  end

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, [:inventory_id, :item_id])
    |> validate_required([:inventory_id, :item_id])
  end
end
