defmodule SjcWeb.UserController do
  @moduledoc false

  use SjcWeb, :controller

  alias Sjc.Repo
  alias Sjc.Models.User

  def create_user(conn, params) do
    changeset = User.changeset(%User{}, params["user"])

    case Repo.insert(changeset) do
      {:ok, %User{} = user} ->
        json(conn, %{user: user})

      {:error, _changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "there was a problem creating your account"})
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
end
