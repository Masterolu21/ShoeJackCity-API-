defmodule SjcWeb.Plugs.AuthErrorHandler do
  @moduledoc false

  use SjcWeb, :controller

  def auth_error(conn, {:unauthenticated, :unauthenticated}, _extra) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: :unauthorized})
  end

  def auth_error(conn, {:invalid_token, _arg}, _extra) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "token is invalid"})
  end
end
