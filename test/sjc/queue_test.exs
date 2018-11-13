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

  describe "add_player/1" do
    test "adds player to queue correctly", %{player: player} do
      :ok = Queue.add(player)
      players = Queue.players()

      assert players == [player]
    end

    test "does not add player if it's already in queue", %{player: player} do
      :ok = Queue.add(player)
      :ok = Queue.add(player)

      players = Queue.players()

      assert players == [player]
    end
  end

  describe "remove_player/1" do
    test "removes player if it's in queue", %{player: player} do
      :ok = Queue.add(player)
      Queue.remove(player["id"])

      assert Queue.players() == []
    end

    test "doesn't do anything if the removed players is not in the queue", %{player: player} do
      :ok = Queue.add(player)
      Queue.remove(921_731)

      assert Queue.players() == [player]
    end
  end
end
