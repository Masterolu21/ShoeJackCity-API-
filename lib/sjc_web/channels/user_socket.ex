defmodule SjcWeb.UserSocket do
  @moduledoc false

  use Phoenix.Socket

  ## Channels
  # channel "room:*", SjcWeb.RoomChannel
  channel("game:lobby", SjcWeb.GameLobby)
  channel("game:*", SjcWeb.GameChannel)

  def connect(%{"jwt_token" => token}, socket) do
    # TODO: DISCUSS TTL OF TOKEN
    case Guardian.decode_and_verify(SjcWeb.Guardian, token) do
      {:ok, token, _claims} ->
        {:ok, assign(socket, :jwt, token)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket), do: :error

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     SjcWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil
end
