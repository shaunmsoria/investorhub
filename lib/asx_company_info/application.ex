defmodule AsxCompanyInfo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AsxCompanyInfoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:asx_company_info, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AsxCompanyInfo.PubSub},
      # Start a worker by calling: AsxCompanyInfo.Worker.start_link(arg)
      # {AsxCompanyInfo.Worker, arg},
      # Start to serve requests, typically the last entry
      AsxCompanyInfoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AsxCompanyInfo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AsxCompanyInfoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
