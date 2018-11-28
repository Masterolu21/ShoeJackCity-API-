defmodule Sjc.Models.User.Inventory do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Sjc.Models.{User, Item}

  schema "inventories" do
    belongs_to(:user, User)

    many_to_many(:items, Item, join_through: "inventory_items")

    timestamps()
  end

  def changeset(%__MODULE__{} = inventory, params \\ %{}) do
    inventory
    |> cast(params, [:user_id])
    |> validate_required(:user_id)
  end
end
