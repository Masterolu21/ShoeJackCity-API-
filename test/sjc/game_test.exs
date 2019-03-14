defmodule Sjc.GameTest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Sjc.DataCase

  import Tesla.Mock

  alias Sjc.Supervisors.GameSupervisor
  alias Sjc.{Game, Repo}
  alias Sjc.Models.{InventoryItems}
  alias Sjc.Models.User.Inventory

  setup do
    mock_global(fn env -> env end)

    player_attributes = build(:player)
    game = build(:game)

    {:ok, pid} = GameSupervisor.start_child(game.name)

    :sys.get_state(pid)

    {:ok, player_attrs: player_attributes, pid: pid, name: game.name}
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

  test "shows the elapsed time", %{name: game_name} do
    assert Timex.is_valid?(Game.state(game_name).time_of_round)
  end

  test "doesn't add existing players when adding from a list", %{
    player_attrs: player1,
    name: game_name
  } do
    player = %{player1 | id: 2}

    players =
      2
      |> build_list(:player)
      |> List.insert_at(-1, player)

    {:ok, :added} = Game.add_player(game_name, [player])

    # We just add the whole list so we don't loop through all of them.
    {:ok, :added} = Game.add_player(game_name, players)

    assert length(Game.state(game_name).players) == 3
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
        "id" => item.id
      },
      %{
        "from" => pp.id,
        "to" => p.id,
        "type" => "damage",
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

    assert Enum.all?(hps, &(&1 == 30))
  end

  test "remove dead players", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)
    {item, player} = build_player_attrs()
    {_item, player_2} = build_player_attrs()

    Game.add_player(game_name, [player, player_2])

    :sys.replace_state(pid, fn state ->
      updated_players = Enum.map(state.players, &Map.put(&1, :health_points, 10))

      put_in(state, [:players], updated_players)
    end)

    assert length(Game.state(game_name).players) == 2

    # Player 1 eliminates player 2.
    action = [
      %{
        "from" => player.id,
        "type" => "damage",
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
        "id" => item.id
      },
      %{
        "from" => pp.id,
        "type" => "shield",
        "id" => item2.id
      }
    ]

    Game.add_action(game_name, actions)

    Process.send(pid, :round_timeout, [:nosuspend])

    # There are no dead players at this stage

    players = Game.state(game_name).players
    hps = Enum.map(players, & &1.health_points)

    # Hp of attacked user is 15.6, we're rounding to the nearest integer = 16
    assert 34 in hps
  end

  test "removes shields from every player alive", %{pid: pid, name: game_name} do
    Game.shift_automatically(game_name)
    {item, p} = build_player_attrs()
    {item2, pp} = build_player_attrs()
    {item3, ppp} = build_player_attrs()

    get_shields = fn -> Enum.map(Game.state(game_name).players, & &1.shield_points) end

    Game.add_player(game_name, [p, pp, ppp])

    # * All players have 0 shield points at start. We must explicitly change this.
    :sys.replace_state(pid, fn state ->
      updated_players = Enum.map(state.players, &Map.put(&1, :shield_points, 50))

      put_in(state, [:players], updated_players)
    end)

    actions = [
      %{
        "from" => p.id,
        "type" => "shield",
        "id" => item.id
      },
      %{
        "from" => pp.id,
        "type" => "shield",
        "id" => item2.id
      },
      %{
        "from" => ppp.id,
        "type" => "shield",
        "id" => item3.id
      }
    ]

    Game.add_action(game_name, actions)

    # * items should be applied.
    Process.send(pid, :round_timeout, [:nosuspend])

    assert get_shields.() == [70, 70, 70]

    Process.send(pid, :standby_phase, [:nosuspend])

    :timer.sleep(500)

    # * shields should be removed at this point
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

    :timer.sleep(1000)

    assert game_state.().actions == []
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

    assert Game.state(game_name).actions == []
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

    inventory = Repo.one(from(i in Inventory, where: i.user_id == ^player.id))
    used_item = get_inventory_item(inventory.id, item.id)

    used_item |> Ecto.Changeset.change(%{quantity: 5}) |> Repo.update!()

    # Used items are removed on :round_timeout
    Process.send(pid, :round_timeout, [:nosuspend])

    state = Game.state(game_name)

    # There's only one player in this game.
    curr_item =
      state.players
      |> Enum.at(0)
      |> Map.get(:inventory)
      |> Enum.at(0)

    updated_item = get_inventory_item(inventory.id, curr_item.id)

    assert updated_item.quantity == 4
  end

  defp build_player_attrs do
    item = insert(:item)
    user = insert(:user)
    player = build(:player, inventory: [item])

    insert(:inventory, items: [item], user: user)

    {item, Map.put(player, :id, user.id)}
  end

  defp get_inventory_item(inventory_id, item_id) do
    Repo.one(
      from(i in InventoryItems,
        where: i.inventory_id == ^inventory_id,
        where: i.item_id == ^item_id
      )
    )
  end
end
