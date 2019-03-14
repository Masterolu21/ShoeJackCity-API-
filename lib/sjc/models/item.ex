defmodule Sjc.Models.Item do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Sjc.Models.{User.Inventory, InventoryItems}

  schema "items" do
    field(:name, :string)
    field(:damage, :integer)
    field(:reduce, :integer)
    field(:effect, :string)
    field(:chance, :integer)
    field(:mpc, :integer)
    field(:prereq, :string)

    many_to_many(:inventories, Inventory, join_through: InventoryItems)

    timestamps()
  end

  def changeset(%__MODULE__{} = item, params \\ %{}) do
    item
    |> cast(params, ~w(name damage effect chance mpc prereq)a)
  end
end
