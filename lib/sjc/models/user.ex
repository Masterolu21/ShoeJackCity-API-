defmodule Sjc.Models.User do
  @moduledoc """
  Main schema for the User table
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Sjc.Models.User.Inventory

  schema "users" do
    field(:email, :string, null: false)
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)
    field(:password_hash, :string)
    field(:points, :integer, default: 0)

    has_one(:inventory, Inventory)

    timestamps()
  end

  def changeset(%__MODULE__{} = player, %{} = args) do
    player
    |> cast(args, ~w(email password password_confirmation)a)
    |> validate_required(~w(email password password_confirmation)a)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> hash_pwd()
  end

  defp hash_pwd(%Ecto.Changeset{valid?: true, changes: %{password: pwd}} = changeset) do
    change(changeset, Comeonin.Argon2.add_hash(pwd))
  end

  defp hash_pwd(changeset), do: changeset
end
