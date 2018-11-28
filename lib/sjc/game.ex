defmodule Sjc.Game do
  @moduledoc """
  Top level Module to manage games.
  """

  use GenServer

  require Logger

  alias Sjc.Repo
  alias Sjc.Models.{User, User.Inventory}
  alias Sjc.Game.{Player, Inventory}
  alias Sjc.GameBackup

  # API

  ## TODO: STANDBY PHASE - APPLY STATUS EFFECTS / REMOVE DEAD PLAYERS / 20% CHANCE MINI WINDOW
  ## TODO: POINTS FOR DEFEATED PLAYERS: 10 * NUMBER OF ROUNDS LASTED
  def start_link(name) do
    state = %{
      round: %{
        number: 1
      },
      players: [],
      actions: [],
      name: name,
      shift_automatically: true,
      time_of_round: Timex.now(),
      backup_pid: nil
    }

    GenServer.start_link(__MODULE__, state, name: via(name))
  end

  def next_round(name) do
    GenServer.cast(via(name), :next_round)
  end

  def remove_player(name, identifier) do
    GenServer.cast(via(name), {:remove_player, identifier})
  end

  # Called through the websocket each time a person changes their action
  def add_action(name, action) do
    GenServer.cast(via(name), {:add_action, action})
  end

  def clean_game(name) do
    GenServer.cast(via(name), :clean_game)
  end

  def state(name) do
    GenServer.call(via(name), :state)
  end

  # We can send a list as 'attributes' so we add all the players in a single operation
  def add_player(name, attributes) do
    GenServer.call(via(name), {:add_player, attributes})
  end

  def shift_automatically(name) do
    GenServer.call(via(name), :shift_automatically)
  end

  def time_of_round_left(name) do
    GenServer.call(via(name), :time_of_round_left)
  end

  # Register new processes per lobby, identified by 'name'.
  defp via(name) do
    {:via, Registry, {:game_registry, name}}
  end

  # Server

  def init(state) do
    pid = get_backup_pid(state)
    backup_state = GameBackup.recover_state(state.name)
    schedule_round_timeout(state.name)

    Process.flag(:trap_exit, true)

    {:ok, %{backup_state | backup_pid: pid}, timeout()}
  end

  defp get_backup_pid(state) do
    case GameBackup.start_link(state) do
      {:ok, pid} -> pid
      {:error, {_reason, pid}} -> pid
    end
  end

  defp schedule_round_timeout(name) do
    Process.send_after(get_pid(name), :round_timeout, round_timeout())
  end

  def terminate(:normal, _state), do: :ok
  def terminate(_reason, state), do: GameBackup.save_state(state.name, state)

  def handle_cast(:next_round, %{round: %{number: round_num}, name: name} = state) do
    new_round = round_num + 1

    # TODO: SEND REQUEST TO RAILS ENDPOINT WITH THE ACTIONS USED A.K.A. ITEMS

    new_state =
      state
      |> put_in([:round, :number], new_round)
      |> put_in([:time_of_round], Timex.now())
      |> put_in([:actions], [])
      |> update_in([:players, Access.all()], &Map.put(&1, :shield_points, 0))

    # TODO: DO A REQUEST TO THE RAILS ENDPOINT TO REMOVE ITEMS USED BY THE USER - ARRAY OR INDIVIDUALLY
    # TODO: EVALUATE IF THIS SHOULD BE DONE AT THE START OF THE ROUND OR WHEN IT'S FINISHING

    # We send a signal to the channel because a round has just passed
    SjcWeb.Endpoint.broadcast("game:" <> name, "next_round", %{number: new_round})

    {:noreply, new_state, timeout()}
  end

  def handle_cast({:remove_player, identifier}, state) do
    players = Enum.reject(state.players, &(&1.id == identifier))

    {:noreply, put_in(state.players, players), timeout()}
  end

  # 'action' / 'actions' should come in a map with some keys, :from, :amount, :type
  # where :type should be one of "shield", "damage".
  def handle_cast({:add_action, actions}, %{players: players} = state) when is_list(actions) do
    ids = Enum.map(players, & &1.id)

    # Only add actions from IDs that are currently in the game.
    new_actions =
      Enum.reduce(actions, [], fn action, acc ->
        case action["from"] in ids do
          true -> acc ++ [action]
          false -> acc
        end
      end)

    new_state = put_in(state, [:actions], new_actions ++ state.actions)

    {:noreply, new_state, timeout()}
  end

  def handle_cast({:add_action, action}, %{players: players} = state) when is_map(action) do
    # TODO: CHECK IF ANY VALIDATION NEEDS TO BE DONE HERE
    ids = Enum.map(players, & &1.id)
    new_state = put_in(state, [:actions], [action] ++ state.actions)

    case action["from"] in ids do
      true -> {:noreply, new_state, timeout()}
      false -> {:noreply, new_state, timeout()}
    end
  end

  def handle_cast(:clean_game, state) do
    init_state =
      state
      |> put_in([:players], [])
      |> put_in([:actions], [])
      |> put_in([:round, :number], 1)
      |> put_in([:shift_automatically], true)

    case Application.get_env(:sjc, :env) == :test do
      true -> {:noreply, init_state, timeout()}
      false -> {:noreply, state, timeout()}
    end
  end

  # Returns the whole process state
  def handle_call(:state, _from, state) do
    {:reply, state, state, timeout()}
  end

  # We still need to check if the player already exists or not but in this case
  # we're not going to reply back with an error, instead we're just going to remove the duplicate.
  def handle_call({:add_player, attributes}, _from, state) when is_list(attributes) do
    # We add both lists and remove duplicates by ID.
    players =
      attributes
      |> Enum.map(&struct(Player, &1))
      |> Kernel.++(state.players)
      |> Enum.uniq_by(& &1.id)

    # We're always going to reply the same unless the process crashes.
    {:reply, {:ok, :added}, put_in(state.players, players), timeout()}
  end

  # # Adds player if it doesn't exist yet.
  # def handle_call({:add_player, attrs}, _from, state) do
  #   player_struct = struct(Player, attrs)
  #   # Inventory MUST be a list, in the case it isn't a list we're just going to
  #   # make it a list and flatten the result.
  #   player_inventory =
  #     [player_struct.inventory]
  #     |> List.flatten()
  #     |> Enum.map(&struct(Inventory, &1))

  #   player = put_in(player_struct, [Access.key(:inventory)], player_inventory)
  #   new_state = update_in(state, [:players], &List.insert_at(&1, -1, player))

  #   # We only allow 99 as the amount of a single item per user in a game.
  #   amounts_on_inventory =
  #     [player.inventory]
  #     |> List.flatten()
  #     |> Enum.map(& &1.amount)

  #   cond do
  #     Enum.any?(state.players, &(&1.id == attrs.id)) ->
  #       {:reply, {:error, :already_added}, state, timeout()}

  #     length(player.inventory) > 200 ->
  #       {:reply, {:error, :exceeded_inventory_limit}, state, timeout()}

  #     Enum.any?(amounts_on_inventory, &(&1 > 99)) ->
  #       {:reply, {:error, :exceeded_item_limit}, state, timeout()}

  #     length(new_state.players) > 1_000 ->
  #       {:reply, {:error, :max_length}, state, timeout()}

  #     true ->
  #       {:reply, {:ok, :added}, new_state, timeout()}
  #   end
  # end

  # When testing or when we don't want to automatically shift rounds we call this function.
  def handle_call(:shift_automatically, _from, state) do
    # If true, make it false, true otherwise.
    will_shift? = !state.shift_automatically

    {:reply, will_shift?, %{state | shift_automatically: will_shift?}, timeout()}
  end

  # This is mainly for players that join or refresh the window or whatever so we know how
  # much time is left in the current round.
  def handle_call(:time_of_round_left, _from, state) do
    remaining = Timex.diff(Timex.now(), state.time_of_round, :seconds)

    {:reply, remaining, state, timeout()}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info(:round_timeout, %{players: players, actions: actions} = state) do
    # @dev We get the ids of the players that are in the game, we remove the id of the
    # person from the action for bombs and use the same id for shields

    shields = Enum.filter(actions, &(&1["type"] == "shield"))
    bombs = Enum.filter(actions, &(&1["type"] == "damage"))

    updated_players =
      Enum.reduce(shields ++ bombs, players, fn action, acc ->
        # We need to get all the ids first.
        ids = Enum.map(players, & &1.id)

        # If 'type' is a bomb then we select a random ID except the user
        # If shield then the target is the user itself.
        target = get_target(ids, action)

        player_index = Enum.find_index(players, &(&1.id == target))

        do_action(acc, action, player_index)
      end)

    Process.send_after(get_pid(state.name), :standby_phase, 5_000)

    {:noreply, put_in(state, [:players], updated_players), timeout()}
  end

  def handle_info(:standby_phase, state) do
    # TODO: CHECK WHAT WE CAN DO HERE AFTER OR BEFORE REMOVING DEAD PLAYERS
    remove_dead_players(state)
  end

  defp get_target(ids, %{"type" => "damage"} = action) do
    # We need to remove the user who sent the action in this case.
    targets = Enum.reject(ids, &(&1 == action["from"]))

    case targets == [] do
      true -> 0
      false -> Enum.random(targets)
    end
  end

  defp get_target(_ids, %{"type" => "shield"} = action) do
    action["from"]
  end

  defp do_action(players, %{"type" => "damage"} = action, index) when not is_nil(index) do
    # Check if user has a shield active
    # TODO: PLAYER HEALTH IS FLOAT INSTEAD OF INTEGERS
    shield_amount = get_in(players, [Access.at(index), Access.key(:shield_points)])
    damage_after_shield = action["amount"] * shield_amount / 100
    final_damage_taken = Kernel.round(action["amount"] - damage_after_shield)

    players
    |> update_in([Access.at(index), Access.key(:health_points)], &(&1 - final_damage_taken))
    |> remove_used_item(action, index)
  end

  # Amount in shield should be a percentage from the damage to be removed.
  defp do_action(players, %{"type" => "shield"} = action, index) when not is_nil(index) do
    players
    |> update_in([Access.at(index), Access.key(:shield_points)], &(&1 + action["amount"]))
    |> remove_used_item(action, index)
  end

  # Catch everything else, no recognized type, nil fields, etc...
  defp do_action(players, _type, _index) do
    players
  end

  defp remove_used_item(players, action, arg_index) do
    # Since we are sending the index of the target instead of the player who sent the action
    # here we're checking if the action type is damage, in that case we need to get the
    # index of the player sent the action to remove the item from the inventory
    # otherwise we just stick with the index of the person who sent the action (shield) which would be correct in that case.
    index =
      case action["type"] == "damage" do
        true -> Enum.find_index(players, &(&1.id == action["from"]))
        false -> arg_index
      end

    update_in(players, [Access.at(index), Access.key(:inventory), Access.all()], fn inv ->
      case inv.item_id == action["id"] do
        true -> Map.put(inv, :amount, inv.amount - 1)
        false -> inv
      end
    end)
  end

  defp remove_dead_players(state) do
    # Players with less than 1 hp are removed and those with nil values.
    {dead_players, new_players} =
      state.players
      |> Enum.reject(fn player -> nil in Map.values(player) end)
      |> Enum.split_with(&(&1.health_points < 1))

    ## TODO: 20% PROBABILITY FOR A WINDOW TO APPEAR AT THE END IF A PLAYER HAS DIED.
    # Probability for an event to happen, in this case, giving a chance for the users to live again.
    case :rand.uniform(100) <= 20 do
      true ->
        # TODO: SEND A MESSAGE TO THE SOCKET OF EACH DEAD PLAYER
        Enum.each(dead_players, fn player -> player end)

      false ->
        # TODO: DO REQUEST TO AWARD POINTS TO DEAD PLAYERS FOR EACH ROUND THEY LASTED
        # TODO: SEND MESSAGE TO SOCKET TO NOTIFY THE PLAYER THE POINTS THEY GAINED
        payload =
          Enum.map(dead_players, fn player ->
            points_awarded = 10 * state.round.number

            %{"player" => player.id, "points" => points_awarded, "rounds" => state.round.number}
          end)
    end

    # We schedule the round timeout here so the 'handle_cast/2' function doesn't call
    # 'Process.send_after/3' when the function is called manually.
    if state.shift_automatically, do: schedule_round_timeout(state.name)

    # TODO: MAYBE ADD A LITTLE DELAY BEFORE TRIGGERING THE NEXT ROUND
    handle_cast(:next_round, put_in(state, [:players], new_players))
  end

  def get_pid(name) do
    [{pid, _}] = Registry.lookup(:game_registry, name)
    pid
  end

  # Timeout is just the time a GenServer (Game process) can stay alive without
  # receiving any messages, defaults to 1 hour.
  # 1 hour without receiving any messages = die.
  defp timeout do
    Application.fetch_env!(:sjc, :game_timeout)
  end

  defp round_timeout do
    Application.fetch_env!(:sjc, :round_timeout)
  end
end
