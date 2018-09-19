defmodule SjcWeb.Router do
  use SjcWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/v1", SjcWeb do
    pipe_through(:api)

    post("/init_game", GameController, :init_game)
    post("/add_player", GameController, :add_player)
  end
end
