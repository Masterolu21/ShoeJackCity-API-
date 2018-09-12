defmodule Sjc.GameTest do
  @moduledoc false

  use Sjc.DataCase

  alias Sjc.Supervisors.GameSupervisor
  alias Sjc.Game

  setup do
    player_attributes = build(:player)

    {:ok, player_attrs: player_attributes}
  end

  describe "game" do
    test "adds another round to the game" do
      GameSupervisor.start_child("game_1")

      # True by default, changes it to false so it doesn't call next round automatically.
      Game.shift_automatically("game_1")

      Game.next_round("game_1")

      assert Game.state("game_1").round.number == 2
    end

    test "process dies after specified time" do
      # Timeout in test is just 1 second, 1 hour normally.
      {:ok, pid} = GameSupervisor.start_child("game_2")

      Game.shift_automatically("game_2")

      assert Process.alive?(pid)

      # Don't send message in more time than the timeout specified
      :timer.sleep(2000)

      refute Process.alive?(pid)
    end

    test "creates a player struct correctly", %{player_attrs: attributes} do
      GameSupervisor.start_child("game_1")

      assert {:ok, :added} = Game.add_player("game_1", attributes)
      assert length(Game.state("game_1").players) == 1
    end

    test "returns {:error, already added} when player is a duplicate", %{player_attrs: attributes} do
      GameSupervisor.start_child("game_5")

      assert {:ok, :added} = Game.add_player("game_5", attributes)
      assert {:error, :already_added} = Game.add_player("game_5", attributes)
    end

    test "removes player from game by identifier", %{player_attrs: attributes} do
      {:ok, _} = GameSupervisor.start_child("game_7")
      {:ok, :added} = Game.add_player("game_7", attributes)

      players_fn = fn -> length(Game.state("game_7").players) end

      # Player length at this point
      assert players_fn.() == 1

      Game.remove_player("game_7", attributes.id)

      assert players_fn.() == 0
    end

    test "automatically shifts round when a specified amount of time has passed" do
      {:ok, _} = GameSupervisor.start_child("game_8")

      assert Game.state("game_8").round.number >= 1
    end

    test "shows the elapsed time" do
      {:ok, _} = GameSupervisor.start_child("game_9")

      assert Timex.is_valid?(Game.state("game_9").time_of_round)
    end

    test "doesn't add existing players when adding from a list", %{player_attrs: player1} do
      {:ok, _} = GameSupervisor.start_child("game_9")
      players = [player1, build(:player), build(:player)]

      # We'll use an existing game in this case
      {:ok, :added} = Game.add_player("game_9", player1)

      # We just add the whole list since so we don't loop through all of them,
      # otherwise we could have sticked with the previous solution of looping
      # through each player's attributes.
      {:ok, :added} = Game.add_player("game_9", players)

      # We should only have 3 players since id 1 was already added
      assert length(Game.state("game_9").players) == 3
    end

    test "should run given actions" do
      {:ok, pid} = GameSupervisor.start_child("game_10")
      Game.shift_automatically("game_10")

      # This way we can test adding by a list and we have the IDS we need.
      p = build(:player)
      pp = build(:player)
      players = [p, pp]

      # Manually send the signal
      Game.add_player("game_10", players)

      players = Game.state("game_10").players

      actions = [
        %{"from" => p.id, "to" => pp.id, "type" => "damage", "amount" => 4.8},
        %{"from" => pp.id, "to" => pp.id, "type" => "shield", "amount" => 3.0},
        %{"from" => p.id, "to" => p.id, "type" => "shield", "amount" => 5.0},
        %{"from" => pp.id, "to" => p.id, "type" => "damage", "amount" => 4.0}
      ]

      Game.add_action("game_10", actions)

      Process.send(pid, :round_timeout, [:nosuspend])

      updated_players = Game.state("game_10").players

      # Players state should have changed.
      refute updated_players == players
      assert length(Game.state("game_10").players) == 2

      hps = Enum.map(updated_players, & &1.health_points)

      assert 46.0 in hps && 45.2 in hps
    end

    @tag :only
    test "remove dead players" do
      {:ok, pid} = GameSupervisor.start_child("game_11")
      Game.shift_automatically("game_11")
      player = build(:player)
      player_2 = build(:player)

      Game.add_player("game_11", [player, player_2])

      assert length(Game.state("game_11").players) == 2

      # Player 1 kills player 2
      action = [%{"from" => player.id, "to" => player_2.id, "type" => "damage", "amount" => 51.0}]

      Game.add_action("game_11", action)

      # Manually running actions
      Process.send(pid, :round_timeout, [:nosuspend])
      Process.send(pid, :standby_phase, [:nosuspend])

      assert length(Game.state("game_11").players) == 1
    end

    test "allows only 1000 players per game" do
      {:ok, _pid} = GameSupervisor.start_child("game_13")

      Enum.each(1..1_000, fn _ -> Game.add_player("game_13", build(:player)) end)

      assert {:error, :max_length} = Game.add_player("game_13", build(:player))
    end
  end
end
