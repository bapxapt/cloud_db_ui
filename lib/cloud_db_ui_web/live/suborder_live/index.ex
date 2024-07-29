defmodule CloudDbUiWeb.SubOrderLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Orders
  alias Phoenix.LiveView.Socket
  alias CloudDbUiWeb.SubOrderLive.FormComponent
  alias CloudDbUiWeb.FlashTimed

  import CloudDbUiWeb.SubOrderLive.Actions
  import CloudDbUiWeb.{Utilities, JavaScript}

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `edit`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, apply_action(socket, act, params, ~p"/sub-orders")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, delete_suborder(socket, Orders.get_suborder_with_order!(id))}
  end

  @impl true
  def handle_info({FormComponent, {:saved, suborder}}, socket) do
    {:noreply, stream_insert(socket, :suborders, suborder)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, _params, true = _connected?) do
    socket
    |> stream_suborders()
    |> FlashTimed.clear_after()
  end

  defp prepare_socket(socket, _prms, false), do: stream(socket, :suborders, [])

  @spec stream_suborders(%Socket{}) :: %Socket{}
  defp stream_suborders(socket) do
    stream(
      socket,
      :suborders,
      Orders.list_suborders_with_product_and_order_user()
    )
  end
end
