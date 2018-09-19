defmodule SjcWeb.GameControllerTest do
  @moduledoc false

  use SjcWeb.ConnCase

  setup do
    player = build(:player)

    {:ok, player: player}
  end

  test "should correctly create a game", %{conn: conn} do
    response =
      conn
      |> post(game_path(conn, :init_game), game_name: "some name")
      |> json_response(200)

    assert %{"game_name" => "some name"} = response
  end

  test "should add player to existing game", %{player: player, conn: conn} do
    post(conn, game_path(conn, :init_game), game_name: "some name")

    response =
      conn
      |> post(game_path(conn, :add_player), player: player, game_name: "some name")
      |> json_response(200)

    assert %{"response" => "added"} = response
  end
end
