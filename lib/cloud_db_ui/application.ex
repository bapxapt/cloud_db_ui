defmodule CloudDbUi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CloudDbUiWeb.Telemetry,
      CloudDbUi.Repo,
      {DNSCluster, query: Application.get_env(:cloud_db_ui, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CloudDbUi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CloudDbUi.Finch},
      # Start a worker by calling: CloudDbUi.Worker.start_link(arg)
      # {CloudDbUi.Worker, arg},
      # Start to serve requests, typically the last entry
      CloudDbUiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CloudDbUi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CloudDbUiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
