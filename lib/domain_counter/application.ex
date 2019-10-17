defmodule DomainCounter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @port 8080

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: DomainCounter, options: [port: @port]},
      {Redix, host: "localhost", name: :redis}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DomainCounter.Supervisor]

    Logger.info("Starting application at localhost:#{@port}/...")

    Supervisor.start_link(children, opts)
  end
end
