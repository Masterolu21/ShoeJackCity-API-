defmodule Sjc.Mixfile do
  use Mix.Project

  def project do
    [
      app: :sjc,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "SJC",
      source_url: "https://github.com/Copywright/sjc-tournaments",
      docs: docs()
    ]
  end

  def application do
    [
      mod: {Sjc.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.4.0"},
      {:plug_cowboy, "~> 2.0"},
      {:plug, "~> 1.7"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:gettext, "~> 0.11"},
      {:timex, "~> 3.3"},
      {:observer_cli, "~> 1.3"},
      {:tesla, "~> 1.1"},
      {:jason, "~> 1.1"},
      {:comeonin, "~> 4.1"},
      {:guardian, "~> 1.1"},
      {:argon2_elixir, "~> 1.2"},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:ex_machina, "~> 2.2", only: :test},
      {:sobelow, "~> 0.7.0", only: [:dev, :test]},
      {:credo, "~> 0.9.3", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test --trace"]
    ]
  end

  defp docs do
    [
      main: "endpoints",
      extras: [
        "docu/endpoints.md"
      ]
    ]
  end
end
