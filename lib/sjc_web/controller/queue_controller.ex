defmodule SjcWeb.QueueController do
  @moduledoc """
  Module in charge of directing incoming requests to the queue system.
  """

  use SjcWeb, :controller

  alias Sjc.Queue

  def add_player(conn, params) do
    json(conn, %{status: Queue.add(params["game"], params["player"])})
  end
end
