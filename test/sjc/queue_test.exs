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

  describe "add_player/2" do
    test "adds player to queue correctly", %{player: player} do
      :ok = Queue.add(2, player)
      players = Queue.players(2)

      assert players == [player]
    end

    test "does not add player if it's already in queue", %{player: player} do
      :ok = Queue.add(3, player)
      :ok = Queue.add(3, player)

      players = Queue.players(3)

      assert players == [player]
    end
  end

  describe "remove_player/2" do
    test "removes player if it's in queue", %{player: player} do
      :ok = Queue.add(3, player)
      Queue.remove(3, player["id"])

      assert Queue.players(3) == []
    end

    test "doesn't do anything if the removed players is not in the queue", %{player: player} do
      :ok = Queue.add(7, player)
      Queue.remove(4, 921_731)

      assert Queue.players(7) == [player]
    end
  end
end
