defmodule SjcWeb.QueueController do
  @moduledoc """
  Module in charge of directing incoming requests to the queue system.
  """

  use SjcWeb, :controller

  alias Sjc.Queue

  def add_player(conn, params) do
    status = %{status: Queue.add(params["game"], params["player"])}

    render(conn, "add_player.json", status)
  end
end
