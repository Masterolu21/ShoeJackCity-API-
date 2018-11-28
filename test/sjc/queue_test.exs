defmodule Sjc.QueueTest do
  @moduledoc false

  use Sjc.DataCase

  alias Sjc.{Queue, Game}

  setup do
    # This way we get a string keys.
    player = string_params_for(:player)
    day_str = Timex.now() |> Timex.day() |> to_string()

    {:ok, player: player, day: day_str}
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

    test "if player is in queue, removes them from existing game and adds them to another one", %{
      player: player
    } do
      Queue.add(1, player)
      "added" = Queue.add(2, player)

      assert Queue.players(1) == []
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

  test "game is created automatically when time is reached", %{day: day_str} do
    :timer.sleep(1_100)

    assert Game.state("#{day_str}_1")
  end

  test "game gets created and adds all the players from the queue to it", %{day: day_str} do
    Enum.each(1..100, fn _ ->
      player = string_params_for(:player)
      Queue.add(1, player)
    end)

    :timer.sleep(1_500)

    game = Game.state("#{day_str}_1")

    assert length(game.players) == 100
  end

  test "queue only allows 99 of a single item on the inventory", %{player: player} do
    item = %{"amount" => 100, "item_id" => 15_123, "multiplier" => 4}
    updated_player = put_in(player, ["inventory"], [item | player["inventory"]])

    assert "exceeded item limit" == Queue.add(2, updated_player)
  end
end
