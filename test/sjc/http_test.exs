defmodule Sjc.HTTPTest do
  @moduledoc false

  use Sjc.DataCase, async: false

  import Tesla.Mock

  alias Sjc.HTTP

  setup do
    mock_global(fn
      %{method: :post, url: "http://url.com/api/v1/remove_used_items"} ->
        json(%{"removed" => true})

      %{method: :post, url: "http://url.com/api/v1/dead_players_points"} ->
        json([%{"awarded" => 80, "to" => 41}])
    end)

    :ok
  end

  test "should send actions used" do
    data = [%{"from" => 124, "item" => 5, "amount" => 1}]

    assert {:ok, %Tesla.Env{} = env} = HTTP.post("/api/v1/remove_used_items", data)
    assert env.body == %{"removed" => true}
    assert env.status == 200
  end

  test "should award points to dead players for rounds lasted" do
    data = [%{"player" => 41, "points" => 80, "rounds" => 8}]

    assert {:ok, %Tesla.Env{} = env} = HTTP.post("/api/v1/dead_players_points", data)
    assert env.body == [%{"awarded" => 80, "to" => 41}]
    assert env.status == 200
  end
end
