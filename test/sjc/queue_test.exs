defmodule Sjc.QueueTest do
  @moduledoc false

  use Sjc.DataCase, async: false

  import ExUnit.CaptureLog
  import Ecto.Query, only: [from: 2]

  alias Sjc.{Queue, Repo}
  alias Sjc.Models.InventoryItems

  setup do
    # This way we get a string keys.
    user = insert(:user)
    items = insert_list(4, :item)
    player = :player |> string_params_for() |> Map.put("id", user.id)
    inventory = insert(:inventory, items: items, user: user)
    day_str = Timex.now() |> Timex.day() |> to_string()

    {:ok, player: player, day: day_str, items: items, user: user, inventory: inventory}
  end

  setup do
    Queue.clean()

    :ok
  end

  describe "add/2" do
    test "adds player to queue correctly", %{player: player} do
      "added" = Queue.add(2, player)
      players = Queue.players(2)

      assert players == [player]
    end

    test "does not add player if it's already in queue", %{player: player} do
      "added" = Queue.add(3, player)
      "already added" = Queue.add(3, player)

      players = Queue.players(3)

      assert players == [player]
    end

    test "if player is in queue, removes them from existing game and adds them to another one", %{
      player: player
    } do
      Queue.add(1, player)
      "added" = Queue.add(2, player)

      assert Queue.players(1) == []
    end
  end

  describe "remove/2" do
    test "removes player if it's in queue", %{player: player} do
      Queue.add(3, player)
      Queue.remove(3, player["id"])

      assert Queue.players(3) == []
    end

    test "doesn't do anything if the removed players is not in the queue", %{player: player} do
      Queue.add(7, player)
      Queue.remove(4, 921_731)

      assert Queue.players(7) == [player]
    end
  end

  test "game is created automatically when time is reached", %{day: day_str} do
    assert capture_log(fn ->
             :timer.sleep(1_500)
           end) =~ "[GAME CREATED] #{day_str}_1"
  end

  test "queue only allows 99 of a single item on the inventory", %{
    player: player,
    inventory: inventory,
    items: items
  } do
    item = Enum.at(items, 0)

    query =
      from(i in InventoryItems,
        where: i.inventory_id == ^inventory.id,
        where: i.item_id == ^item.id,
        update: [set: [quantity: 100]]
      )

    Repo.update_all(query, [])

    assert "exceeded item limit" == Queue.add(2, player)
  end

  test "queue only allows 200 items in a single inventory", %{player: player} do
    items =
      Enum.map(1..201, fn id ->
        %{"amount" => Enum.random(1..50), "item_id" => id, "multiplier" => 2}
      end)

    updated_player = put_in(player, ["inventory"], items ++ player["inventory"])

    assert "exceeded inventory limit" == Queue.add(3, updated_player)
  end

  # defp build_player_attrs do
  #   item = insert(:item)
  #   user = insert(:user)
  #   inventory = insert(:inventory, items: [item], user: user)
  #   insert(:inventory_items, item: item, inventory: inventory)

  #   player =
  #     build(:player,
  #       inventory: [%{id: item.id, amount: item.amount, multiplier: item.multiplier}]
  #     )

  #   inventory = Enum.map(player.inventory, &Map.take(&1, ~w(id amount multiplier)a))

  #   %{
  #     id: player.id,
  #     inventory: inventory
  #   }
  #   |> Jason.encode!()
  #   |> Jason.decode!()
  # end
end
