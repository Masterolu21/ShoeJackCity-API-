defmodule Sjc.HTTP do
  @moduledoc """
  Module in charge of sending out request to other endpoints from the game process.
  """

  use Tesla

  alias Tesla.Middleware

  plug(Middleware.BaseUrl, "http://url.com")
  plug(Middleware.JSON, engine: Jason)

  def send_used_items(object) do
    post("/api/v1/remove_items_used", object)
  end

  def dead_players_points(object) do
    post("/api/v1/dead_players_points", object)
  end
end
