defmodule CloudDbUiWeb.SubOrderLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  import CloudDbUiWeb.SubOrderLive.Actions
  import CloudDbUiWeb.{Utilities, HTML}

  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUiWeb.SubOrderLive.FormComponent
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  @type params() :: CloudDbUi.Type.params()

  # TODO: the app layout does not get rendered if a 404 exception happens during a connected mount()
    # TODO: this does not happen during a disconnected mount()

  # TODO: get a sub-order with preloaded :order with preloaded :user?

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
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

  # TODO: def handle_info({FormComponent, {:saved, suborder, _refilter?}}, socket) do

  @impl true
  def handle_info({FormComponent, {:saved, suborder}}, socket) do
    {:noreply, assign(socket, :suborder, suborder)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, %{"id" => suborder_id}, true = _connected?) do
    socket
    |> assign(:suborder, Orders.get_suborder_with_full_preloads!(suborder_id))
    |> assign(:load_images?, CloudDbUiWeb.ImageServer.up?())
    |> FlashTimed.clear_after()
  end

  defp prepare_socket(socket, %{"id" => _} = _params, false = _connected?) do
    socket
    |> assign(:suborder, nil)
    |> FlashTimed.clear_after()
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

  @spec paid(%SubOrder{}) :: String.t()
  defp paid(%{order: %{paid_at: at}}), do: (if at, do: "Yes", else: "No")
end
