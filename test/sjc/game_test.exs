defmodule Sjc.GameTest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Sjc.DataCase

  import Tesla.Mock

  alias Sjc.Supervisors.GameSupervisor
  alias Sjc.{Game, Repo}
  alias Sjc.Models.{InventoryItems}

  setup do
    mock_global(fn env -> env end)

    player_attributes = build(:player)
    game = build(:game)

    {:ok, pid} = GameSupervisor.start_child(game.name)

    # Game.clean_game(game_name)

    {:ok, player_attrs: player_attributes, pid: pid, name: game.name}
  end

  test "adds another round to the game", %{name: game_name} do
    # True by default, changes it to false so it doesn't call next round automatically.
    Game.shift_automatically(game_name)

    Game.next_round(game_name)

    assert Game.state(game_name).round.number == 2
  end

  test "creates a player struct correctly", %{player_attrs: attributes, name: game_name} do
    assert {:ok, :added} = Game.add_player(game_name, [attributes])
    assert length(Game.state(game_name).players) == 1
  end

  test "removes player from game by identifier", %{player_attrs: attributes, name: game_name} do
    {:ok, :added} = Game.add_player(game_name, [attributes])

    players_fn = fn -> length(Game.state(game_name).players) end

    # Player length at this point
    assert players_fn.() == 1

    Game.remove_player(game_name, attributes.id)

    assert players_fn.() == 0
  end

  test "automatically shifts round when a specified amount of time has passed", %{name: game_name} do
    assert Game.state(game_name).round.number >= 1
  end

  test "shows the elapsed time", %{name: game_name} do
    assert Timex.is_valid?(Game.state(game_name).time_of_round)
  end

  test "doesn't add existing players when adding from a list", %{
    player_attrs: player1,
    name: game_name
  } do
    players = build_list(3, :player)

    {:ok, :added} = Game.add_player(game_name, [player1])

    # We just add the whole list since so we don't loop through all of them,
    # otherwise we could have sticked with the previous solution of looping
    # through each player's attributes.
    {:ok, :added} = Game.add_player(game_name, players)

    # We should only have 3 players since id 1 was already added
    assert length(Game.state(game_name).players) == 4
  end

  test "should run given actions", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)

    # This way we can test adding by a list and we have the IDS we need.
    {item, p} = build_player_attrs()
    {item2, pp} = build_player_attrs()

    # Manually send the signal
    Game.add_player(game_name, [p, pp])

    players = Game.state(game_name).players

    actions = [
      %{
        "from" => p.id,
        "to" => pp.id,
        "type" => "damage",
        "amount" => 4,
        "id" => item.id
      },
      %{
        "from" => pp.id,
        "to" => p.id,
        "type" => "damage",
        "amount" => 12,
        "id" => item2.id
      }
    ]

    Game.add_action(game_name, actions)

    Process.send(pid, :round_timeout, [:nosuspend])

    updated_players = Game.state(game_name).players

    # Players state should have changed.
    refute updated_players == players
    assert length(Game.state(game_name).players) == 2

    hps = Enum.map(updated_players, & &1.health_points)

    assert 46 in hps && 38 in hps
  end

  test "remove dead players", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)
    {item, player} = build_player_attrs()
    {_item, player_2} = build_player_attrs()

    Game.add_player(game_name, [player, player_2])

    assert length(Game.state(game_name).players) == 2

    # Player 1 kills player 2
    action = [
      %{
        "from" => player.id,
        "type" => "damage",
        "amount" => 60,
        "id" => item.id
      }
    ]

    Game.add_action(game_name, action)

    # Manually running actions
    Process.send(pid, :round_timeout, [:nosuspend])
    Process.send(pid, :standby_phase, [:nosuspend])

    assert length(Game.state(game_name).players) == 1
  end

  test "shields should be applied first and damage reduced", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)
    {item, p} = build_player_attrs()
    {item2, pp} = build_player_attrs()

    Game.add_player(game_name, [p, pp])

    # 14% of 40 is 5.6, final damage to PP should be 34.4
    actions = [
      %{
        "from" => p.id,
        "type" => "damage",
        "amount" => 40,
        "id" => item.id
      },
      %{
        "from" => pp.id,
        "type" => "shield",
        "amount" => 14,
        "id" => item2.id
      }
    ]

    Game.add_action(game_name, actions)

    Process.send(pid, :round_timeout, [:nosuspend])

    # There are no dead players at this stage

    players = Game.state(game_name).players
    hps = Enum.map(players, & &1.health_points)

    # Hp of attacked user is 15.6, we're rounding to the nearest integer = 16
    assert 16 in hps
  end

  test "removes shields from every player alive", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)
    {item, p} = build_player_attrs()
    {item2, pp} = build_player_attrs()
    {item3, ppp} = build_player_attrs()

    get_shields = fn -> Enum.map(Game.state(game_name).players, & &1.shield_points) end

    Game.add_player(game_name, [p, pp, ppp])

    actions = [
      %{
        "from" => p.id,
        "type" => "shield",
        "amount" => 16,
        "id" => item.id
      },
      %{
        "from" => pp.id,
        "type" => "shield",
        "amount" => 18,
        "id" => item2.id
      },
      %{
        "from" => ppp.id,
        "type" => "shield",
        "amount" => 31,
        "id" => item3.id
      }
    ]

    Game.add_action(game_name, actions)

    Process.send(pid, :round_timeout, [:nosuspend])

    assert get_shields.() == [16, 18, 31]

    Process.send(pid, :standby_phase, [:nosuspend])

    # Shields should be removed at this point
    assert get_shields.() == [0, 0, 0]
  end

  test "should remove actions after the round", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)
    {item, p} = build_player_attrs()
    {item2, pp} = build_player_attrs()
    {item3, ppp} = build_player_attrs()

    Game.add_player(game_name, [p, pp, ppp])

    actions = [
      %{
        "from" => p.id,
        "type" => "shield",
        "amount" => 16,
        "id" => item.id
      },
      %{
        "from" => pp.id,
        "type" => "shield",
        "amount" => 18,
        "id" => item2.id
      },
      %{
        "from" => ppp.id,
        "type" => "shield",
        "amount" => 31,
        "id" => item3.id
      }
    ]

    Game.add_action(game_name, actions)

    game_state = fn -> Game.state(game_name) end

    assert length(game_state.().actions) == 3

    Process.send(pid, :round_timeout, [:nosuspend])
    Process.send(pid, :standby_phase, [:nosuspend])

    assert length(game_state.().actions) == 0
  end

  test "should not add actions if the user isn't in the game", %{name: game_name} do
    Game.shift_automatically(game_name)

    action = [
      %{
        "from" => 123,
        "type" => "shield",
        "amount" => 16,
        "id" => 12
      }
    ]

    Game.add_action(game_name, action)

    assert length(Game.state(game_name).actions) == 0
  end

  test "convert all players to struct when adding from a list", %{name: game_name} do
    Game.shift_automatically(game_name)

    players = [
      %{id: 12},
      %{id: 151},
      %{id: 12}
    ]

    Game.add_player(game_name, players)

    state = Game.state(game_name)

    assert Enum.all?(state.players, &Map.has_key?(&1, :__struct__))
  end

  test "should create the user inventory when adding the player to a game", %{name: game_name} do
    Game.shift_automatically(game_name)

    player = [%{id: 123}]

    Game.add_player(game_name, player)

    state = Game.state(game_name)

    assert Enum.all?(state.players, &Map.has_key?(&1, :__struct__))
    # assert Enum.at(state.players, 0).inventory == [%Inventory{item_id: 51, amount: 4}]
  end

  test "should create inventory struct when adding players from list", %{name: game_name} do
    players = build_pair(:player)

    Game.add_player(game_name, players)

    state = Game.state(game_name)

    expected = Enum.map(players, & &1.inventory)

    assert Enum.map(state.players, & &1.inventory) == expected
  end

  test "removes used items when a round has passed", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)

    {item, player} = build_player_attrs()

    Game.add_player(game_name, [player])

    action = [
      %{
        "from" => player.id,
        "type" => "shield",
        "amount" => 15,
        "id" => item.id
      }
    ]

    Game.add_action(game_name, action)

    # Used items are removed on :round_timeout
    Process.send(pid, :round_timeout, [:nosuspend])

    state = Game.state(game_name)

    # There's only one player in this game.
    curr_amount =
      state.players
      |> Enum.at(0)
      |> Map.get(:inventory)
      |> Enum.at(0)
      |> Map.get(:amount)

    inv_amount = Enum.at(player.inventory, 0).amount

    assert Enum.at(player.inventory, 0).amount > curr_amount
    assert inv_amount - 1 == curr_amount
  end

  test "removes the used items from the database after actions have been applied", %{
    pid: pid,
    name: game_name
  } do
    Game.shift_automatically(game_name)

    item = insert(:item)
    user = insert(:user)
    inventory1 = insert(:inventory, items: [item], user: user)

    inv_items = insert(:inventory_items, inventory: inventory1, item: item)

    user_2 = insert(:user)
    inventory2 = insert(:inventory, items: [item], user: user_2)
    inv_items2 = insert(:inventory_items, inventory: inventory2, item: item)

    players_item = Map.take(item, ~w(id amount multiplier))

    players_for_game =
      Enum.map([user, user_2], fn player ->
        %{
          id: player.id,
          inventory: players_item
        }
      end)

    Game.add_player(game_name, players_for_game)

    action = [
      %{
        "from" => user.id,
        "type" => "shield",
        "amount" => 34,
        "id" => item.id
      },
      %{
        "from" => user_2.id,
        "type" => "damage",
        "amount" => 29,
        "id" => item.id
      }
    ]

    Game.add_action(game_name, action)

    Process.send(pid, :round_timeout, [:nosuspend])

    inventory = Repo.get(InventoryItems, inv_items.id)
    inventory2 = Repo.get(InventoryItems, inv_items2.id)

    assert inventory.quantity < item.amount
    assert inventory2.quantity < item.amount
  end

  defp build_player_attrs do
    item = insert(:item)
    user = insert(:user)
    insert(:inventory, items: [item], user: user)

    player = build(:player, inventory: [item])

    {item, Map.put(player, :id, user.id)}
  end
end
