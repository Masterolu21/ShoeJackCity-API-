defmodule SjcWeb.Router do
  use SjcWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :authenticated do
    plug(SjcWeb.Plugs.AuthPipeline)
  end

  scope "/api/v1", SjcWeb do
    pipe_through([:api, :authenticated])

    scope "/queue" do
      post("/add_player", QueueController, :add_player)
    end

    scope "/users" do
      get("/get_user:id", UserController, :get_user)
    end
  end

  scope "/api/v1", SjcWeb do
    pipe_through(:api)

    scope "/users" do
      post("/create_user", UserController, :create_user)
      post("/sign_in", UserController, :sign_in)
    end
  end
end
