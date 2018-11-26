defmodule SjcWeb.UserController do
  @moduledoc false

  use SjcWeb, :controller

  import Comeonin.Argon2, only: [checkpw: 2, dummy_checkpw: 0]

  alias Sjc.Repo
  alias Sjc.Models.User

  def create_user(conn, params) do
    changeset = User.changeset(%User{}, params["user"])

    with {:ok, %User{} = user} <- Repo.insert(changeset),
         {:ok, token, _claims} <- encode_resource(user) do
      render(conn, "create_user.json", %{user: user, jwt: token})
    else
      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_status(:bad_request)
        |> render("create_user_changeset_error.json", %{
          error: "there was a problem creating your account"
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> render("create_user_bad_req.json", %{error: reason})
    end
  end

  def sign_in(conn, %{"email" => email, "password" => password}) do
    case email_pass_auth(email, password) do
      {:ok, token, _claims} ->
        render(conn, "sign_in.json", %{jwt: token})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> render("sign_in_unauthorized.json", %{error: :unauthorized})
    end
  end

  defp email_pass_auth(nil, _password), do: :error
  defp email_pass_auth(_email, nil), do: :error

  defp email_pass_auth(email, password) do
    with %User{} = user <- Repo.get_by(User, email: email),
         true <- checkpw(password, user.password_hash),
         {:ok, token, claims} <- encode_resource(user) do
      {:ok, token, claims}
    else
      nil ->
        dummy_checkpw()
        :error
    end
  end

  def get_user(conn, %{"id" => user_id}) do
    case Repo.get(User, user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(SjcWeb.ErrorView)
        |> render("404.json", [])

      %User{} = user ->
        user_dropped = Map.drop(user, ~w(password password_confirmation password_hash)a)

        render(conn, "get_user.json", %{user: user_dropped})
    end
  end

  defp encode_resource(res) do
    Guardian.encode_and_sign(SjcWeb.Guardian, res)
  end
end
