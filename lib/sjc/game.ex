defmodule Sjc.Game do
  @moduledoc """
  Top level Module to manage games.
  """

  use GenServer

  require Logger

  alias Sjc.Game.Player
  alias Sjc.GameBackup

  # API

  # TODO: Check what can stay in the process and what should be in the database
  # we can pull a reference and just use the information from the database in the process
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

  def add_round_actions(name, actions) do
    GenServer.cast(via(name), {:add_actions, actions})
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

    new_state =
      state
      |> put_in([:round, :number], new_round)
      |> put_in([:time_of_round], Timex.now())
      # Remove players that have less than 0 HP.
      |> remove_dead_players()

    # We send a signal to the channel because a round has just passed
    SjcWeb.Endpoint.broadcast("game:" <> name, "next_round", %{number: new_round})

    {:noreply, new_state, timeout()}
  end

  def handle_cast({:remove_player, identifier}, state) do
    players = Enum.reject(state.players, &(&1.id == identifier))

    {:noreply, put_in(state.players, players), timeout()}
  end

  def handle_cast({:add_actions, actions}, state) when is_list(actions) do
    # 'actions' should come in a map with some keys, :from, :to, :amount, :type
    # where :type should be one of "shield", "damage".
    players = run_actions(actions, state)

    new_state =
      state
      |> put_in([:players], players)
      |> put_in([:actions], [])

    {:noreply, new_state, timeout()}
  end

  # Returns the whole process state
  def handle_call(:state, _from, state) do
    {:reply, state, state, timeout()}
  end

  # We still need to check if the player already exists or not but in this case
  # we're not going to reply back with an error, instead we're just going to remove the duplicate.
  def handle_call({:add_player, attributes}, _from, state) when is_list(attributes) do
    # We add both lists and remove duplicates by ID.
    players = Enum.uniq_by(state.players ++ attributes, & &1.id)

    # We're gonna always reply the same unless the process crashes
    {:reply, {:ok, :added}, put_in(state.players, players), timeout()}
  end

  # Adds player if it doesn't exist yet.
  def handle_call({:add_player, attrs}, _from, state) do
    player = struct(Player, attrs)
    new_state = update_in(state, [:players], &List.insert_at(&1, -1, player))

    cond do
      Enum.any?(state.players, &(&1.id == attrs.id)) ->
        {:reply, {:error, :already_added}, state, timeout()}

      length(new_state.players) > 1_000 ->
        {:reply, {:error, :max_length}, state, timeout()}

      true ->
        {:reply, {:ok, :added}, new_state, timeout()}
    end
  end

  # When testing or when we don't want to automatically shift rounds we call this function.
  # @dev what happens here is that when you a specific process then you interrupt the timeout()
  # in each return of a 'handle_*' call, which would make the process to live forever even when
  # not in use. This also makes it impossible to test if a process dies within the specified time
  # in timeout/0
  def handle_call(:shift_automatically, _from, state) do
    # If true, make it false, true otherwise.
    will_shift? = !state.shift_automatically

    {:reply, will_shift?, %{state | shift_automatically: will_shift?}, timeout()}
  end

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

  def handle_info(:round_timeout, state) do
    # We schedule the round timeout here so the 'handle_cast/2' function doesn't call
    # 'Process.send_after/3' when the function is called manually.
    if state.shift_automatically, do: schedule_round_timeout(state.name)

    handle_cast(:next_round, state)
  end

  # Timeout is just the time a GenServer (Lobby process) can stay alive without
  # receiving any messages, defaults to 1 hour.
  # 1 hour without receiving any messages = die.
  defp timeout do
    Application.fetch_env!(:sjc, :game_timeout)
  end

  defp round_timeout do
    Application.fetch_env!(:sjc, :round_timeout)
  end

  defp run_actions(actions, %{players: players}) do
    actions
    |> Enum.reduce(players, fn action, acc ->
      player_index = Enum.find_index(players, &(&1.id == action["to"]))

      do_type(acc, action["type"], player_index, action["amount"])
    end)
    |> Enum.map(&struct(Player, &1))
  end

  # TODO: Players have shield points too, we're only removing health_points here for now.
  # TODO: Shields should only reduce damage from bombs
  defp do_type(players, "damage", index, amount) do
    update_in(players, [Access.at(index), :health_points], &(&1 - amount))
  end

  defp do_type(players, "shield", index, amount) do
    update_in(players, [Access.at(index), :shield_points], &(&1 + amount))
  end

  defp do_type(players, _type, _index, _amount) do
    players
  end

  defp remove_dead_players(state) do
    new_players =
      state.players
      |> Enum.reject(&(&1.health_points <= 0))
      |> Enum.reject(fn player -> nil in Map.values(player) end)

    Enum.reject(state.players, &(&1.health_points <= 0))

    put_in(state, [:players], new_players)
  end

  def get_pid(name) do
    [{pid, _}] = Registry.lookup(:game_registry, name)
    pid
  end
end
