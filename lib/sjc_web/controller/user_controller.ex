defmodule SjcWeb.UserController do
  @moduledoc false

  use SjcWeb, :controller

  alias Sjc.Repo
  alias Sjc.Models.User

  def create_user(conn, params) do
    changeset = User.changeset(%User{}, params["user"])

    with {:ok, %User{} = user} <- Repo.insert(changeset),
         {:ok, token, _claims} <- encode_resource(user) do
      json(conn, %{user: user, jwt: token})
    else
      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "there was a problem creating your account"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def get_user(conn, %{"id" => user_id}) do
    case Repo.get(User, user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not found"})

      %User{} = user ->
        user_dropped = Map.drop(user, ~w(password password_confirmation password_hash)a)

        json(conn, %{user: user_dropped})
    end
  end

  defp encode_resource(res) do
    Guardian.encode_and_sign(SjcWeb.Guardian, res)
  end
end
