defmodule Sjc.Queue do
  @moduledoc """
  Queue system for Sjc.
  Since we don't have any system for pairing, this module just adds player to the queue and once the
  requirements for a game are met we create said game and move all the players there.

  The queue will work as follows. Once initiated, there will be some data populated. 10 games per day.

  Each game has the time it'll start and players on it.
  """

  # TODO: CHANGE TYPES (CALL / CAST) SINCE WE NEED REPLIES FOR THESES ACTIONS

  use GenServer

  @tz "America/Caracas"

  def start_link do
    GenServer.start_link(__MODULE__, populate_state(), name: :queue_sys)
  end

  defp populate_state do
    interval = Application.get_env(:sjc, :game_intervals)

    {_, state} =
      Enum.reduce(1..10, {Timex.now(@tz), %{}}, fn game, {last_time, acc} ->
        time_for_game = Timex.shift(last_time, interval)

        data = %{
          start_time: time_for_game,
          players: []
        }

        {time_for_game, Map.put(acc, game, data)}
      end)

    state
  end

  def clean do
    GenServer.cast(:queue_sys, :clean)
  end

  def add(game, %{"id" => _id} = player)
      when is_integer(game) and game > 0 and game < 10 do
    GenServer.call(:queue_sys, {:add_player, game, player})
  end

  def remove(game, player_id)
      when is_integer(player_id) and is_integer(game) and game > 0 and game < 10 do
    GenServer.call(:queue_sys, {:remove_player, game, player_id})
  end

  def state do
    GenServer.call(:queue_sys, :state)
  end

  def players(game)
      when is_integer(game) and game > 0 and game < 10 do
    GenServer.call(:queue_sys, {:player_list, game})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast(:clean, state) do
    case Application.get_env(:sjc, :env) do
      :test -> {:noreply, populate_state()}
      _ -> {:noreply, state}
    end
  end

  # Adds player only if it's not in the queue for the same game already.
  def handle_call({:add_player, game, player}, _from, state) do
    players_in_game =
      state
      |> Map.get(game)
      |> Map.get(:players)

    cond do
      length(players_in_game) >= 1_000 ->
        {:reply, "maximum amount reached", state}

      Enum.any?(players_in_game, &(&1["id"] == player["id"])) ->
        {:reply, "already added", state}

      true ->
        # This function will traverse all the games players and remove the players with the same ID as the incoming one.
        # Meaning that this will also work to remove from a game and add the player to another one.
        game_state =
          state
          |> Enum.reduce(%{}, fn {id, game}, acc ->
            rej_opt = Enum.reject(game.players, &(&1["id"] == player["id"]))
            players = put_in(game[:players], rej_opt)

            Map.put(acc, id, players)
          end)
          |> update_in([game, :players], &List.insert_at(&1, -1, player))

        {:reply, "added", game_state}
    end
  end

  def handle_call({:remove_player, game, id}, _from, state) do
    players =
      state
      |> Map.get(game)
      |> Map.get(:players)
      |> Enum.reject(&(&1["id"] == id))

    {:reply, "removed", put_in(state, [game, :players], players)}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:player_list, game}, _from, state) do
    players = state |> Map.get(game) |> Map.get(:players)
    {:reply, players, state}
  end
end
