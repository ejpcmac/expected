defmodule Expected.Mixfile do
  use Mix.Project

  @version "0.1.1"
  @repo_url "https://github.com/ejpcmac/expected"

  def project do
    [
      app: :expected,
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [:unmatched_returns, :error_handling, :race_conditions],
        ignore_warnings: ".dialyzer_ignore"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      docs: [
        main: "Expected",
        source_url: @repo_url,
        source_ref: "v#{@version}"
      ],
      package: package(),
      description: "An Elixir application for login and session management."
    ]
  end

  def application do
    [
      mod: {Expected, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Development and test dependencies
      {:credo, "~> 0.8.10", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:excoveralls, ">= 0.0.0", only: :test, runtime: false},
      {:mix_test_watch, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_unit_notifier, ">= 0.0.0", only: :test, runtime: false},
      {:export_private, ">= 0.0.0", runtime: false},

      # Project dependencies
      {:plug, "~> 1.4"},

      # Documentation dependencies
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Jean-Philippe Cugnet"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
