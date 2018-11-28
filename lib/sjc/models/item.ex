defmodule Sjc.Models.Item do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "items" do
    field(:amount, :integer)
    field(:multiplier, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = item, params \\ %{}) do
    item
    |> cast(params, [:amount, :multiplier])
    |> validate_required([:amount, :multiplier])
  end
end
