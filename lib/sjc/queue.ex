defmodule Sjc.Queue do
  @moduledoc """
  Queue system for Sjc.
  Since we don't have any system for pairing, this module just adds player to the queue and once the
  requirements for a game are met we create said game and move all the players there.

  The queue will work as follows. Once initiated, there will be some data populated. 10 games per day.

  Each game has the time it'll start and players on it.
  """

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

  def add(game, %{"id" => _id} = player) when is_integer(game) do
    GenServer.cast(:queue_sys, {:add_player, game, player})
  end

  def remove(game, player_id)
      when is_integer(player_id)
      when is_integer(game) do
    GenServer.cast(:queue_sys, {:remove_player, game, player_id})
  end

  def clean do
    GenServer.cast(:queue_sys, :clean)
  end

  def state do
    GenServer.call(:queue_sys, :state)
  end

  def players(game) when is_integer(game) do
    GenServer.call(:queue_sys, {:player_list, game})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:add_player, game, player}, state) do
    # Adds player only if it's not in the queue already
    # TODO: Plaer shouldn't be in two games at the same time.
    op =
      state
      |> Map.get(game)
      |> Map.get(:players)
      |> Enum.any?(&(&1["id"] == player["id"]))

    case op do
      true -> {:noreply, state}
      false -> {:noreply, update_in(state, [game, :players], &List.insert_at(&1, -1, player))}
    end
  end

  def handle_cast({:remove_player, game, id}, state) do
    players =
      state
      |> Map.get(game)
      |> Map.get(:players)
      |> Enum.reject(&(&1["id"] == id))

    {:noreply, put_in(state, [game, :players], players)}
  end

  def handle_cast(:clean, state) do
    case Application.get_env(:sjc, :env) do
      :test -> {:noreply, populate_state()}
      _ -> {:noreply, state}
    end
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:player_list, game}, _from, state) do
    players = state |> Map.get(game) |> Map.get(:players)
    {:reply, players, state}
  end
end
