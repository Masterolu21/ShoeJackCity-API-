defmodule Sjc.GameTest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Sjc.DataCase

  import Tesla.Mock

  alias Sjc.Supervisors.GameSupervisor
  alias Sjc.Game

  setup do
    mock_global(fn env -> env end)

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
        %{"from" => p.id, "to" => pp.id, "type" => "damage", "amount" => 4},
        %{"from" => pp.id, "to" => p.id, "type" => "damage", "amount" => 12}
      ]

      Game.add_action("game_10", actions)

      Process.send(pid, :round_timeout, [:nosuspend])

      updated_players = Game.state("game_10").players

      # Players state should have changed.
      refute updated_players == players
      assert length(Game.state("game_10").players) == 2

      hps = Enum.map(updated_players, & &1.health_points)

      assert 46 in hps && 38 in hps
    end

    test "remove dead players" do
      {:ok, pid} = GameSupervisor.start_child("game_11")
      Game.shift_automatically("game_11")
      player = build(:player)
      player_2 = build(:player)

      Game.add_player("game_11", [player, player_2])

      assert length(Game.state("game_11").players) == 2

      # Player 1 kills player 2
      action = [%{"from" => player.id, "type" => "damage", "amount" => 60}]

      Game.add_action("game_11", action)

      # Manually running actions
      Process.send(pid, :round_timeout, [:nosuspend])
      Process.send(pid, :standby_phase, [:nosuspend])

      assert length(Game.state("game_11").players) == 1
    end

    test "allows only 1000 players per game" do
      {:ok, _pid} = GameSupervisor.start_child("game_13")
      Game.shift_automatically("game_13")

      Enum.each(1..1_000, fn _ -> Game.add_player("game_13", build(:player)) end)

      assert {:error, :max_length} = Game.add_player("game_13", build(:player))
    end

    test "shields should be applied first and damage reduced" do
      {:ok, pid} = GameSupervisor.start_child("game_14")
      Game.shift_automatically("game_14")
      p = build(:player)
      pp = build(:player)

      Game.add_player("game_14", [p, pp])

      # 14% of 40 is 5.6, final damage to PP should be 34.4
      actions = [
        %{"from" => p.id, "type" => "damage", "amount" => 40},
        %{"from" => pp.id, "type" => "shield", "amount" => 14}
      ]

      Game.add_action("game_14", actions)

      Process.send(pid, :round_timeout, [:nosuspend])

      # There are no dead players at this stage

      players = Game.state("game_14").players
      hps = Enum.map(players, & &1.health_points)

      # Hp of attacked user is 15.6, we're rounding to the nearest integer = 16
      assert 16 in hps
    end

    test "removes shields from every player alive" do
      {:ok, pid} = GameSupervisor.start_child("game_15")
      Game.shift_automatically("game_15")
      p = build(:player)
      pp = build(:player)
      ppp = build(:player)

      get_shields = fn -> Enum.map(Game.state("game_15").players, & &1.shield_points) end

      Game.add_player("game_15", [p, pp, ppp])

      actions = [
        %{"from" => p.id, "type" => "shield", "amount" => 16},
        %{"from" => pp.id, "type" => "shield", "amount" => 18},
        %{"from" => ppp.id, "type" => "shield", "amount" => 31}
      ]

      Game.add_action("game_15", actions)

      Process.send(pid, :round_timeout, [:nosuspend])

      assert get_shields.() == [16, 18, 31]

      Process.send(pid, :standby_phase, [:nosuspend])

      # Shields should be removed at this point
      assert get_shields.() == [0, 0, 0]
    end

    @tag :only
    test "should remove actions after the round" do
      {:ok, pid} = GameSupervisor.start_child("game_16")
      Game.shift_automatically("game_16")
      p = build(:player)
      pp = build(:player)
      ppp = build(:player)

      Game.add_player("game_16", [p, pp, ppp])

      actions = [
        %{"from" => p.id, "type" => "shield", "amount" => 16},
        %{"from" => pp.id, "type" => "shield", "amount" => 18},
        %{"from" => ppp.id, "type" => "shield", "amount" => 31}
      ]

      Game.add_action("game_16", actions)

      game_state = fn -> Game.state("game_16") end

      assert length(game_state.().actions) == 3

      Process.send(pid, :round_timeout, [:nosuspend])
      Process.send(pid, :standby_phase, [:nosuspend])

      assert length(game_state.().actions) == 0
    end

    test "should not add actions if the user isn't in the game" do
      {:ok, _pid} = GameSupervisor.start_child("game_17")
      Game.shift_automatically("game_17")

      action = [%{"from" => 123, "type" => "shield", "amount" => 16}]

      Game.add_action("game_17", action)

      assert length(Game.state("game_17").actions) == 0
    end
  end
end
