defmodule CloudDbUiWeb.Telemetry do
  use Supervisor

  import Telemetry.Metrics

  alias Telemetry.Metrics.Summary

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10000 ms. Learn more here: https://hexdocs.pm/telemetry_metrics.
      {:telemetry_poller, measurements: periodic_measurements(), period: 10000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec metrics() :: [%Summary{}]
  def metrics() do
    [
      # Phoenix metrics.
      phoenix_summary("endpoint.start.system_time"),
      phoenix_summary("endpoint.stop.duration"),
      phoenix_summary("router_dispatch.start.system_time", [:route]),
      phoenix_summary("router_dispatch.exception.duration", [:route]),
      phoenix_summary("router_dispatch.stop.duration", [:route]),
      phoenix_summary("socket_connected.duration"),
      sum("phoenix.socket_drain.count"),
      phoenix_summary("channel_joined.duration"),
      phoenix_summary("channel_handled_in.duration", [:event]),
      # Data base metrics.
      data_base_summary("total_time", "The sum of the other measurements"),
      data_base_summary(
        "decode_time",
        "The time spent decoding the data received from the data base"
      ),
      data_base_summary("query_time", "The time spent executing the query"),
      data_base_summary(
        "queue_time",
        "The time spent waiting for a data base connection"
      ),
      data_base_summary(
        "idle_time",
        data_base_summary_idle_time_description()
      ),
      # VM metrics.
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  @spec periodic_measurements() :: [{module(), atom(), [any()]}]
  defp periodic_measurements() do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {CloudDbUiWeb, :count_users, []}
    ]
  end

  @spec phoenix_summary(String.t(), [atom()] | nil) :: %Summary{}
  defp phoenix_summary(metric_name_part, tags \\ nil) do
    opts =
      maybe_put_new([unit: {:native, :millisecond}], :tags, tags)

    summary("phoenix." <> metric_name_part, opts)
  end

  @spec data_base_summary(String.t(), String.t() | nil) :: %Summary{}
  defp data_base_summary(metric_name_part, desc) do
    opts =
      maybe_put_new([unit: {:native, :millisecond}], :description, desc)

    summary("cloud_db_ui.repo.query." <> metric_name_part, opts)
  end

  # Put the `value` under the `key`, unless the `value` is `nil`
  @spec maybe_put_new(keyword(), atom(), any()) :: keyword()
  defp maybe_put_new(list, key, value) do
    maybe_put_new(list, key, value, value != nil)
  end

  @spec maybe_put_new(keyword(), atom(), any(), boolean()) :: keyword()
  defp maybe_put_new(list, key, val, true), do: Keyword.put_new(list, key, val)

  defp maybe_put_new(list, _key, _value, false), do: list

  @spec data_base_summary_idle_time_description() :: String.t()
  defp data_base_summary_idle_time_description() do
    Kernel.<>(
      "The time the connection spent waiting before being checked out ",
      "for the query"
    )
  end
end
