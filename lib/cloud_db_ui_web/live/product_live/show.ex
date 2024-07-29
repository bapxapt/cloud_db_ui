defmodule CloudDbUiWeb.ProductLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUiWeb.ProductLive.FormComponent
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.ProductLive.Actions
  import CloudDbUiWeb.{HTML, Utilities}

  @type params() :: CloudDbUi.Type.params()

  # TODO: why can't we use connected?() with prepare_socket() in Show?

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
    {:noreply, apply_action(socket, action, params, ~p"/products/#{id}")}
  end

  @impl true
  def handle_event("order", %{"sub_order" => suborder_params}, socket) do
    {:noreply, order_product!(socket, suborder_params)}
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{product: prod}} = socket) do
    {:noreply, delete_product(socket, prod)}
  end

  @impl true
  def handle_info({FormComponent, {:saved, product, _refilter?}}, socket) do
    {:noreply, assign(socket, :product, product)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, %{"id" => product_id} = _params) do
    socket
    |> assign_product_and_orders!(product_id)
    |> assign(:form, to_form(%{"quantity" => 1}))
    |> FlashTimed.clear_after()
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

  # Check whether to display the "Current image path" list item.
  # Only an admin may see it. If the `product` is `nil`, the list item
  # will be displayed while the socket is not `connected?()`.
  @spec display_current_image_path?(%User{} | nil, %Product{} | nil) ::
          boolean()
  defp display_current_image_path?(%User{admin: true}, nil), do: true

  # `product` is not `nil`.
  defp display_current_image_path?(%User{admin: true}, product) do
    product.image_path != nil
  end

  # The user is `nil`, or is not an administrator.
  defp display_current_image_path?(_user, _product), do: false

  @spec table_header(%Product{} | nil) :: String.t()
  defp table_header(%Product{orders: 0}), do: "No orders with this product."

  # The product is `nil`, or the value of `:orders` is not zero.
  defp table_header(_product), do: "Orders with this product"
end
