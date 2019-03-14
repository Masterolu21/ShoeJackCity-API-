defmodule SjcWeb.Guardian do
  @moduledoc false

  use Guardian, otp_app: :sjc

  alias Sjc.Repo
  alias Sjc.Models.User

  def subject_for_token(nil, _claims) do
    {:error, :missing_resource}
  end

  def subject_for_token(%{id: id}, _claims) do
    case Repo.get(User, id) do
      nil -> {:error, :resource_not_found}
      %User{} = _user -> {:ok, to_string(id)}
    end
  end

  def subject_for_token(_res, _claims) do
    {:error, :invalid_resource}
  end

  def resource_from_claims(%{"sub" => sub}) do
    case Repo.get(User, sub) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end
end
