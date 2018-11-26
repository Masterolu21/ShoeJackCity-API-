defmodule SjcWeb.UserView do
  @moduledoc false

  use SjcWeb, :view

  def render("create_user.json", %{user: user, jwt: token}) do
    %{
      user: %{
        id: user.id,
        email: user.email
      },
      jwt: token
    }
  end

  def render("create_user_changeset_error.json", _error) do
    %{
      error: "there was a problem creating your account"
    }
  end

  def render("create_user_bad_req.json", %{error: error}) do
    %{
      error: error
    }
  end

  def render("sign_in.json", %{jwt: token}) do
    %{
      jwt: token
    }
  end

  def render("sign_in_unauthorized.json", %{error: error}) do
    %{
      error: error
    }
  end

  def render("get_user.json", %{user: user}) do
    %{
      user: %{
        id: user.id,
        email: user.email
      }
    }
  end
end
