defmodule Sjc.QueueTest do
  @moduledoc false

  use Sjc.DataCase

  alias Sjc.Queue

  setup do
    # This way we get a string keys.
    player = :player |> build() |> Jason.encode!() |> Jason.decode!()

    {:ok, player: player}
  end

  setup do
    Queue.clean()

    :ok
  end

  describe "add/2" do
    test "adds player to queue correctly", %{player: player} do
      "added" = Queue.add(2, player)
      players = Queue.players(2)

      assert players == [player]
    end

    test "does not add player if it's already in queue", %{player: player} do
      "added" = Queue.add(3, player)
      "already added" = Queue.add(3, player)

      players = Queue.players(3)

      assert players == [player]
    end

    test "does not add player if queue has reached maximum", %{player: player} do
      Enum.each(1..1_000, fn _ ->
        player_attrs = :player |> build() |> Jason.encode!() |> Jason.decode!()

        Queue.add(2, player_attrs)
      end)

      assert "maximum amount reached" = Queue.add(2, player)
    end
  end

  describe "remove/2" do
    test "removes player if it's in queue", %{player: player} do
      Queue.add(3, player)
      Queue.remove(3, player["id"])

      assert Queue.players(3) == []
    end

    test "doesn't do anything if the removed players is not in the queue", %{player: player} do
      Queue.add(7, player)
      Queue.remove(4, 921_731)

      assert Queue.players(7) == [player]
    end
  end
end
