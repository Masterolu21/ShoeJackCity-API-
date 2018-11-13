defmodule SjcWeb.QueueController do
  @moduledoc """
  Module in charge of directing incoming requests to the queue system.
  """

  use SjcWeb, :controller

  alias Sjc.Queue

  def add_player(conn, params) do
    response =
      case Queue.add(params["player"]) do
        :ok -> "added"
        _ -> "error adding player to queue"
      end

    json(conn, %{status: response})
  end
end
