defmodule Sjc.Queue do
  @moduledoc """
  Queue system for Sjc.
  Since we don't have any system for pairing, this module just adds player to the queue and once the
  requirements for a game are met we create said game and move all the players there.
  """

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{players: []}, name: :queue_sys)
  end

  def add(%{"id" => _id} = player) do
    GenServer.cast(:queue_sys, {:add_player, player})
  end

  def remove(player_id) when is_integer(player_id) do
    GenServer.cast(:queue_sys, {:remove_player, player_id})
  end

  def clean do
    GenServer.cast(:queue_sys, :clean)
  end

  def players do
    GenServer.call(:queue_sys, :player_list)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:add_player, player}, state) do
    # Adds player only if it's not in the queue already
    op = Enum.any?(state.players, &(&1["id"] == player["id"]))

    case op do
      true -> {:noreply, state}
      false -> {:noreply, update_in(state, [:players], &List.insert_at(&1, -1, player))}
    end
  end

  def handle_cast({:remove_player, id}, state) do
    players = Enum.reject(state.players, &(&1["id"] == id))

    {:noreply, put_in(state.players, players)}
  end

  def handle_cast(:clean, state) do
    clean_state = %{players: []}

    case Application.get_env(:sjc, :env) do
      :test -> {:noreply, clean_state}
      _ -> {:noreply, state}
    end
  end

  def handle_call(:player_list, _from, state) do
    {:reply, state.players, state}
  end
end
