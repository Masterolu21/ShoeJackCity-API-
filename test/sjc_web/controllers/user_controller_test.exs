defmodule SjcWeb.UserControllerTest do
  @moduledoc false

  use SjcWeb.ConnCase

  setup do
    user = insert(:user)
    user_params = params_for(:user)

    {:ok, user: user, user_params: user_params}
  end

  describe "create_user/2" do
    test "creates user with correct params", %{conn: conn, user_params: params} do
      %{"user" => user} =
        conn
        |> post(user_path(conn, :create_user), user: params)
        |> json_response(200)

      assert user["email"] == params.email
      assert user["password"] == nil
    end

    test "does not create user if params are missing", %{conn: conn} do
      %{"error" => error} =
        conn
        |> post(user_path(conn, :create_user), user: %{})
        |> json_response(400)

      assert error == "there was a problem creating your account"
    end

    test "returns a valid token when a user has signed-up", %{conn: conn, user_params: params} do
      %{"jwt" => token} =
        conn
        |> post(user_path(conn, :create_user), user: params)
        |> json_response(200)

      assert {:ok, _claims} = Guardian.decode_and_verify(SjcWeb.Guardian, token)
    end
  end

  describe "get_user/2" do
    test "does not return sensitive information of the user", %{conn: conn, user: user} do
      %{"user" => user} =
        conn
        |> get(user_path(conn, :get_user, to_string(user.id)))
        |> json_response(200)

      assert Enum.all?(
               [user["password"], user["password_hash"], user["password_confirmation"]],
               &(&1 == nil)
             )
    end

    test "returns error when user does not exist", %{conn: conn} do
      response =
        conn
        |> get(user_path(conn, :get_user, "999999999999999"))
        |> json_response(404)

      assert %{"error" => "not found"} = response
    end

    test "raises when id is not an integer or ID type", %{conn: conn} do
      assert_raise Ecto.Query.CastError, fn ->
        get(conn, user_path(conn, :get_user, "not an integer"))
      end
    end
  end
end
