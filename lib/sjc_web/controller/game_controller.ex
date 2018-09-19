defmodule SjcWeb.GameController do
  @moduledoc false

  use SjcWeb, :controller

  alias Sjc.Game
  alias Sjc.Supervisors.GameSupervisor

  def init_game(conn, %{"game_name" => name}) do
    {:ok, _pid} = GameSupervisor.start_child(name)

    json(conn, %{game_name: name})
  end

  def add_player(conn, %{"player" => params, "game_name" => name}) do
    res =
      case Game.add_player(name, params) do
        {:ok, :added} -> "added"
        {:error, :max_length} -> "max amount of players per game reached"
        {:error, :already_added} -> "player already exists"
      end

    json(conn, %{response: res})
  end
end
