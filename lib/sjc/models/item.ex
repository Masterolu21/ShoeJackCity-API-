defmodule Sjc.Models.Item do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Sjc.Models.{User.Inventory, InventoryItems}

  schema "items" do
    field(:amount, :integer)
    field(:multiplier, :integer)

    many_to_many(:inventories, Inventory, join_through: InventoryItems)

    timestamps()
  end

  def changeset(%__MODULE__{} = item, params \\ %{}) do
    item
    |> cast(params, [:amount, :multiplier])
    |> validate_required([:amount, :multiplier])
  end
end
