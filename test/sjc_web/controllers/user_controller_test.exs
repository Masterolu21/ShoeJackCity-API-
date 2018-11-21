defmodule SjcWeb.UserControllerTest do
  @moduledoc false

  use SjcWeb.ConnCase

  setup do
    user = insert(:user)
    user_params = params_for(:user)
    {:ok, token, _claims} = Guardian.encode_and_sign(SjcWeb.Guardian, user)

    {:ok, user: user, user_params: user_params, token: token}
  end

  describe "create_user/2" do
    test "creates user with correct params", %{conn: conn, user_params: params, token: token} do
      %{"user" => user} =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(user_path(conn, :create_user), user: params)
        |> json_response(200)

      assert user["email"] == params.email
      assert user["password"] == nil
    end

    test "does not create user if params are missing", %{conn: conn, token: token} do
      %{"error" => error} =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
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
    test "does not return sensitive information of the user", %{
      conn: conn,
      user: user,
      token: token
    } do
      %{"user" => user} =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(user_path(conn, :get_user, to_string(user.id)))
        |> json_response(200)

      assert Enum.all?(
               [user["password"], user["password_hash"], user["password_confirmation"]],
               &(&1 == nil)
             )
    end

    test "returns error when user does not exist", %{conn: conn, token: token} do
      response =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(user_path(conn, :get_user, "999999999999999"))
        |> json_response(404)

      assert %{"error" => "not found"} = response
    end

    test "raises when id is not an integer or ID type", %{conn: conn, token: token} do
      assert_raise Ecto.Query.CastError, fn ->
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(user_path(conn, :get_user, "not an integer"))
      end
    end
  end

  describe "sign_in/2" do
    test "returns jwt when user exists", %{conn: conn, user_params: params} do
      post(conn, user_path(conn, :create_user), user: params)

      %{"jwt" => token} =
        conn
        |> post(user_path(conn, :sign_in), params)
        |> json_response(200)

      assert {:ok, _claims} = Guardian.decode_and_verify(SjcWeb.Guardian, token)
    end

    test "returns error when user is invalid", %{conn: conn} do
      response =
        conn
        |> post(user_path(conn, :sign_in), %{email: "invalid", password: "some password"})
        |> json_response(401)

      assert %{"error" => "unauthorized"} = response
    end
  end
end
