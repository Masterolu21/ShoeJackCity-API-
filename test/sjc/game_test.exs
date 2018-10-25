defmodule Sjc.GameTest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Sjc.DataCase

  import Tesla.Mock

  alias Sjc.Supervisors.GameSupervisor
  alias Sjc.Game.Inventory
  alias Sjc.Game

  setup_all do
    {:ok, pid} = GameSupervisor.start_child("game")

    {:ok, pid: pid}
  end

  setup do
    mock_global(fn env -> env end)

    player_attributes = build(:player)

    Game.clean_game("game")

    {:ok, player_attrs: player_attributes}
  end

  test "adds another round to the game" do
    # True by default, changes it to false so it doesn't call next round automatically.
    Game.shift_automatically("game")

    Game.next_round("game")

    assert Game.state("game").round.number == 2
  end

  test "creates a player struct correctly", %{player_attrs: attributes} do
    assert {:ok, :added} = Game.add_player("game", attributes)
    assert length(Game.state("game").players) == 1
  end

  test "returns {:error, already added} when player is a duplicate", %{player_attrs: attributes} do
    assert {:ok, :added} = Game.add_player("game", attributes)
    assert {:error, :already_added} = Game.add_player("game", attributes)
  end

  test "removes player from game by identifier", %{player_attrs: attributes} do
    {:ok, :added} = Game.add_player("game", attributes)

    players_fn = fn -> length(Game.state("game").players) end

    # Player length at this point
    assert players_fn.() == 1

    Game.remove_player("game", attributes.id)

    assert players_fn.() == 0
  end

  test "automatically shifts round when a specified amount of time has passed" do
    assert Game.state("game").round.number >= 1
  end

  test "shows the elapsed time" do
    assert Timex.is_valid?(Game.state("game").time_of_round)
  end

  test "doesn't add existing players when adding from a list", %{player_attrs: player1} do
    players = build_list(3, :player)

    {:ok, :added} = Game.add_player("game", player1)

    # We just add the whole list since so we don't loop through all of them,
    # otherwise we could have sticked with the previous solution of looping
    # through each player's attributes.
    {:ok, :added} = Game.add_player("game", players)

    # We should only have 3 players since id 1 was already added
    assert length(Game.state("game").players) == 4
  end

  test "should run given actions", %{pid: pid} do
    Game.shift_automatically("game")

    # This way we can test adding by a list and we have the IDS we need.
    p = build(:player)
    pp = build(:player)
    players = [p, pp]

    # Manually send the signal
    Game.add_player("game", players)

    players = Game.state("game").players

    actions = [
      %{"from" => p.id, "to" => pp.id, "type" => "damage", "amount" => 4},
      %{"from" => pp.id, "to" => p.id, "type" => "damage", "amount" => 12}
    ]

    Game.add_action("game", actions)

    Process.send(pid, :round_timeout, [:nosuspend])

    updated_players = Game.state("game").players

    # Players state should have changed.
    refute updated_players == players
    assert length(Game.state("game").players) == 2

    hps = Enum.map(updated_players, & &1.health_points)

    assert 46 in hps && 38 in hps
  end

  test "remove dead players", %{pid: pid} do
    Game.shift_automatically("game")
    player = build(:player)
    player_2 = build(:player)

    Game.add_player("game", [player, player_2])

    assert length(Game.state("game").players) == 2

    # Player 1 kills player 2
    action = [%{"from" => player.id, "type" => "damage", "amount" => 60}]

    Game.add_action("game", action)

    # Manually running actions
    Process.send(pid, :round_timeout, [:nosuspend])
    Process.send(pid, :standby_phase, [:nosuspend])

    assert length(Game.state("game").players) == 1
  end

  test "allows only 1000 players per game" do
    Game.shift_automatically("game")

    Enum.each(1..1_000, fn _ -> Game.add_player("game", build(:player)) end)

    assert {:error, :max_length} = Game.add_player("game", build(:player))
  end

  test "shields should be applied first and damage reduced", %{pid: pid} do
    Game.shift_automatically("game")
    p = build(:player)
    pp = build(:player)

    Game.add_player("game", [p, pp])

    # 14% of 40 is 5.6, final damage to PP should be 34.4
    actions = [
      %{"from" => p.id, "type" => "damage", "amount" => 40},
      %{"from" => pp.id, "type" => "shield", "amount" => 14}
    ]

    Game.add_action("game", actions)

    Process.send(pid, :round_timeout, [:nosuspend])

    # There are no dead players at this stage

    players = Game.state("game").players
    hps = Enum.map(players, & &1.health_points)

    # Hp of attacked user is 15.6, we're rounding to the nearest integer = 16
    assert 16 in hps
  end

  test "removes shields from every player alive", %{pid: pid} do
    Game.shift_automatically("game")
    p = build(:player)
    pp = build(:player)
    ppp = build(:player)

    get_shields = fn -> Enum.map(Game.state("game").players, & &1.shield_points) end

    Game.add_player("game", [p, pp, ppp])

    actions = [
      %{"from" => p.id, "type" => "shield", "amount" => 16},
      %{"from" => pp.id, "type" => "shield", "amount" => 18},
      %{"from" => ppp.id, "type" => "shield", "amount" => 31}
    ]

    Game.add_action("game", actions)

    Process.send(pid, :round_timeout, [:nosuspend])

    assert get_shields.() == [16, 18, 31]

    Process.send(pid, :standby_phase, [:nosuspend])

    # Shields should be removed at this point
    assert get_shields.() == [0, 0, 0]
  end

  test "should remove actions after the round", %{pid: pid} do
    Game.shift_automatically("game")
    p = build(:player)
    pp = build(:player)
    ppp = build(:player)

    Game.add_player("game", [p, pp, ppp])

    actions = [
      %{"from" => p.id, "type" => "shield", "amount" => 16},
      %{"from" => pp.id, "type" => "shield", "amount" => 18},
      %{"from" => ppp.id, "type" => "shield", "amount" => 31}
    ]

    Game.add_action("game", actions)

    game_state = fn -> Game.state("game") end

    assert length(game_state.().actions) == 3

    Process.send(pid, :round_timeout, [:nosuspend])
    Process.send(pid, :standby_phase, [:nosuspend])

    assert length(game_state.().actions) == 0
  end

  test "should not add actions if the user isn't in the game" do
    Game.shift_automatically("game")

    action = [%{"from" => 123, "type" => "shield", "amount" => 16}]

    Game.add_action("game", action)

    assert length(Game.state("game").actions) == 0
  end

  test "convert all players to struct when adding from a list" do
    Game.shift_automatically("game")

    players = [
      %{id: 12, inventory: build(:inventory)},
      %{id: 151, inventory: build(:inventory)},
      %{id: 12, inventory: build(:inventory)}
    ]

    Game.add_player("game", players)

    state = Game.state("game")

    assert Enum.all?(state.players, &Map.has_key?(&1, :__struct__))
  end

  test "should create the user inventory when adding the player to a game" do
    Game.shift_automatically("game")

    player = %{id: 123, inventory: %{item_id: 51, amount: 4}}

    Game.add_player("game", player)

    state = Game.state("game")

    assert Enum.all?(state.players, &Map.has_key?(&1, :__struct__))
    assert Enum.at(state.players, 0).inventory == [%Inventory{item_id: 51, amount: 4}]
  end

  test "should create inventory struct when adding players from list" do
    players = [
      %{id: 12, inventory: %{item_id: 50, amount: 1}},
      %{id: 141, inventory: %{item_id: 40, amount: 12}}
    ]

    Game.add_player("game", players)

    state = Game.state("game")

    expected = [
      [%Inventory{item_id: 50, amount: 1}],
      [%Inventory{item_id: 40, amount: 12}]
    ]

    assert Enum.map(state.players, & &1.inventory) == expected
  end
end
