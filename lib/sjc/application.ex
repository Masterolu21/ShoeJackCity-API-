defmodule Sjc.Application do
  @moduledoc false

  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(Sjc.Repo, []),
      # Start the endpoint when the application starts
      supervisor(SjcWeb.Endpoint, []),
      supervisor(Registry, [:unique, :game_registry], id: 1),
      supervisor(Registry, [:unique, :game_supervisor_registry], id: 2),
      supervisor(Registry, [:unique, :game_backup], id: 3),
      supervisor(Sjc.Supervisors.GameSupervisor, []),
      worker(Sjc.Queue, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sjc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SjcWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
