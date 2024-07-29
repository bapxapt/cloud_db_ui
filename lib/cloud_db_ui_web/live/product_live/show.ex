defmodule CloudDbUiWeb.ProductLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.ProductLive.Actions
  import CloudDbUiWeb.HTML
  import CloudDbUiWeb.Utilities

  @impl true
  def mount(%{"id" => product_id} = _params, _session, socket) do
    socket_new =
      socket
      |> assign_product_and_orders!(product_id)
      |> assign(:form, to_form(%{"quantity" => 1}))
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
    {:noreply, apply_action(socket, action, params, ~p"/products/#{id}")}
  end

  @impl true
  def handle_event("order", %{"sub_order" => suborder_params}, socket) do
    {:noreply, order_product!(socket, Map.put(suborder_params, "product_id", socket.assigns.product.id))}
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{product: prod}} = socket) do
    {:noreply, delete_product(socket, prod)}
  end

  @impl true
  def handle_info(
        {CloudDbUiWeb.ProductLive.FormComponent, {:saved, product}},
        socket
      ) do
    {:noreply, assign(socket, :product, product)}
  end

  # An admin can view a non-orderable product with orders.
  @spec assign_product_and_orders!(%Socket{}, String.t()) :: %Socket{}
  defp assign_product_and_orders!(
         %{assigns: %{current_user: %{admin: true}}} = socket,
         id
       ) do
    product = Products.get_product_with_type_and_order_suborder_users!(id)

    socket
    |> assign(:product, replace_orders_with_count(product))
    |> stream(:orders, product.orders)
  end

  # A user or a guest can view only an orderable product without orders.
  defp assign_product_and_orders!(socket, id) do
    assign(socket, :product, Products.get_orderable_product_with_type!(id))
  end

  # Replace the list of orders with their count.
  @spec replace_orders_with_count(%Product{}) :: %Product{}
  defp replace_orders_with_count(%Product{} = product) do
    product
    |> Map.replace!(
      :paid_orders,
      Enum.count(product.orders, &(&1.paid_at != nil))
    )
    |> Map.replace!(:orders, Enum.count(product.orders))
  end

  @spec table_header(%Product{}) :: String.t()
  defp table_header(%Product{orders: 0}), do: "No orders with this product."

  defp table_header(%Product{}), do: "Orders with this product"
end
