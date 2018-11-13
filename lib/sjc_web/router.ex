defmodule SjcWeb.Router do
  use SjcWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/v1", SjcWeb do
    pipe_through(:api)

    scope "/queue" do
      post("/add_player", QueueController, :add_player)
    end
  end
end
