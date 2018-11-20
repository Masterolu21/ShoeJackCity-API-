defmodule Sjc.Models.UserTest do
  @moduledoc false

  use Sjc.DataCase

  alias Sjc.Repo
  alias Sjc.Models.User

  setup do
    user = insert(:user)
    user_params = params_for(:user)

    {:ok, user: user, user_params: user_params}
  end

  test "password gets hashed when user is created", %{user_params: params} do
    record =
      %User{}
      |> User.changeset(params)
      |> Repo.insert()

    assert {:ok, %User{} = user} = record
    assert user.password == nil
    assert Comeonin.Argon2.checkpw(params.password, user.password_hash)
  end
end
