defmodule SjcWeb.Guardian do
  @moduledoc false

  use Guardian, otp_app: :sjc

  alias Sjc.Repo
  alias Sjc.Models.User

  def subject_for_token(%User{} = resource, _claims) do
    sub = to_string(resource.id)
    {:ok, sub}
  end

  def subject_for_token(nil, _claims) do
    {:error, :missing_resource}
  end

  def subject_for_token(_res, _claims) do
    {:error, :invalid_resource}
  end

  def resource_from_claims(claims) do
    id = claims["sub"]

    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
end
