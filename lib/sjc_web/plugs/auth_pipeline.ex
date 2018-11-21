defmodule SjcWeb.Plugs.AuthPipeline do
  @moduledoc false

  use Guardian.Plug.Pipeline,
    otp_app: :sjc,
    module: SjcWeb.Guardian,
    error_handler: SjcWeb.Plugs.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, realm: "Bearer")
  plug(Guardian.Plug.EnsureAuthenticated)
end
