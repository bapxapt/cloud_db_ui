defmodule CloudDbUiWeb.SubOrderLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUiWeb.FlashTimed

  import CloudDbUiWeb.SubOrderLive.Actions
  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.HTML

  @impl true
  def mount(%{"id" => suborder_id} = _params, _session, socket) do
    socket_new =
      socket
      |> assign(
        :suborder,
        Orders.get_suborder_with_full_preloads!(suborder_id)
      )
      |> assign(:load_images?, CloudDbUiWeb.ImageServer.up?())
      |> FlashTimed.clear_after()

    {:ok, socket_new}
  end

  @impl true
  def handle_params(params, _uri, %{assigns: %{live_action: action}} = socket)
      when action in [:show, :redirect] do
    {:noreply, apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `:edit`).
  def handle_params(
        %{"id" => id} = params,
        _uri,
        %{assigns: %{live_action: action}} = socket
      ) do
    {:noreply, apply_action(socket, action, params, ~p"/sub-orders/#{id}")}
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{suborder: sub}} = socket) do
    {:noreply, delete_suborder(socket, sub)}
  end

  @impl true
  def handle_info(
        {CloudDbUiWeb.SubOrderLive.FormComponent, {:saved, suborder}},
        socket
      ) do
    {:noreply, assign(socket, :suborder, suborder)}
  end

  @spec unit_price(%SubOrder{}) :: String.t()
  defp unit_price(%{product: %{unit_price: current_price}} = suborder) do
    "PLN "
    |> Kernel.<>(format(suborder.unit_price))
    |> Kernel.<>(unit_price_suffix(suborder.unit_price, current_price))
  end

  @spec unit_price_suffix(%Decimal{}, %Decimal{}) :: String.t()
  defp unit_price_suffix(%Decimal{} = saved_price, %Decimal{} = current) do
    case Decimal.compare(saved_price, current) do
      :lt -> " (lower than the current price of PLN #{format(current)})"
      :eq -> " (equal to the current price)"
      :gt -> " (higher than the current price of PLN #{format(current)})"
    end
  end
end
