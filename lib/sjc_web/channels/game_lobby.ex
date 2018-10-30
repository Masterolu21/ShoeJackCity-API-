defmodule SjcWeb.GameLobby do
  @moduledoc """
  In this module we're going to accept all the connections in the lobby.
  We're going to send the users from here to the queue. Once the queue is full for a game
  We're creating the game and sending the users there.
  """

  use Phoenix.Channel

  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end
end
