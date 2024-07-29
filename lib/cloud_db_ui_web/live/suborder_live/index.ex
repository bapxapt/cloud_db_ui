defmodule CloudDbUiWeb.SubOrderLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Orders
  alias Phoenix.LiveView.Socket
  alias CloudDbUiWeb.FlashTimed

  import CloudDbUiWeb.SubOrderLive.Actions
  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript

  @impl true
  def mount(_params, _session, socket) do
    socket_new =
      socket
      |> stream_suborders()
      |> FlashTimed.clear_after()

    {:ok, socket_new}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
  def handle_info(
        {CloudDbUiWeb.SubOrderLive.FormComponent, {:saved, suborder, _}},
        socket
      ) do
    {:noreply, stream_insert(socket, :suborders, suborder)}
  end

  @spec stream_suborders(%Socket{}) :: %Socket{}
  defp stream_suborders(socket) do
    stream(
      socket,
      :suborders,
      Orders.list_suborders_with_product_and_order_user()
    )
  end
end
