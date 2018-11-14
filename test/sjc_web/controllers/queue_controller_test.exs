defmodule SjcWeb.QueueControllerTest do
  @moduledoc false

  use SjcWeb.ConnCase

  alias Sjc.Queue

  setup do
    player = :player |> build() |> Jason.encode!() |> Jason.decode!()

    {:ok, player: player}
  end

  describe "add_player/2" do
    test "adds player from controller correctly", %{conn: conn, player: player} do
      %{"status" => res} =
        conn
        |> post(queue_path(conn, :add_player), player: player, game: 3)
        |> json_response(200)

      players = Queue.players(3)

      assert res == "added"
      assert players == [player]
    end
  end
end
