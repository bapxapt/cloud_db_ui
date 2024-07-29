defmodule CloudDbUiWeb.OrderLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.OrderLive.Actions
  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
  end

  @impl true
  def handle_event("delete", %{"id" => id} = _params, socket) do
    {:noreply, delete_order!(socket, Orders.get_order_with_suborder_ids!(id))}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (actions: `:edit`, `:pay`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, apply_action(socket, act, params, ~p"/orders")}
  end

  @impl true
  def handle_info({_module, {:saved, %Order{} = order}}, socket) do
    {:noreply, stream_insert(socket, :orders, order)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, _params, true = _connected?) do
    socket
    |> assign_orders()
    |> FlashTimed.clear_after()
  end

  defp prepare_socket(socket, _params, false), do: stream(socket, :orders, [])

  # An admin can see any orders.
  @spec assign_orders(%Socket{}) :: %Socket{}
  defp assign_orders(%{assigns: %{current_user: %{admin: true}}} = socket) do
    stream(socket, :orders, Orders.list_orders_with_full_preloads())
  end

  # A user can see only own orders.
  defp assign_orders(%{assigns: %{current_user: user}} = socket) do
    stream(socket, :orders, Orders.list_orders_with_suborder_products(user))
  end
end
