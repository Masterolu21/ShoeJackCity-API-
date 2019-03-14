defmodule SjcWeb.QueueControllerTest do
  @moduledoc false

  use SjcWeb.ConnCase

  alias Sjc.Queue

  setup do
    user = insert(:user)
    items = insert_list(4, :item)
    player = :player |> string_params_for() |> Map.put("id", user.id)

    insert(:inventory, items: items, user: user)

    {:ok, token, _claims} = Guardian.encode_and_sign(SjcWeb.Guardian, user)

    {:ok, player: player, token: token, user: user}
  end

  test "adds player from controller correctly", %{conn: conn, player: player, token: token} do
    %{"status" => res} =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(Routes.queue_path(conn, :add_player), player: player, game: 3)
      |> json_response(200)

    players = Queue.players(3)

    assert res == "added"
    assert players == [player]
  end

  test "returns error when trying to add a player without a valid JWT", %{
    conn: conn,
    player: player
  } do
    response =
      conn
      |> put_req_header("authorization", "Bearer token")
      |> post(Routes.queue_path(conn, :add_player), player: player, game: 2)
      |> json_response(400)

    assert %{"error" => _error} = response
  end
end
