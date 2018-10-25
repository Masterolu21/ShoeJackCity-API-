defmodule SjcWeb.Router do
  use SjcWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/v1", SjcWeb do
    pipe_through(:api)
  end
end
