defmodule DomainCounter.MixProject do
  use Mix.Project

  def project do
    [
      app: :domain_counter,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {DomainCounter.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.1"},
      {:poison, "~> 4.0"},
      {:redix, "~> 0.10.2"},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end
end
