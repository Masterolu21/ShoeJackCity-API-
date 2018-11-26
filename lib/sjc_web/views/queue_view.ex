defmodule SjcWeb.QueueView do
  @moduledoc false

  use SjcWeb, :view

  def render("add_player.json", %{status: status}) do
    %{
      status: status
    }
  end
end
