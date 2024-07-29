defmodule CloudDbUiWeb.ProductLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUiWeb.FlashTimed
  alias CloudDbUiWeb.ImageServer
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.HTML
  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript
  import CloudDbUiWeb.ProductLive.Actions

  @type params :: CloudDbUi.Type.params()

  @impl true
  def mount(_params, _session, socket) do
    socket_new =
      socket
      # For guest (not logged in) visitors.
      |> assign_new(:current_user, fn -> nil end)
      |> stream_products()
      |> assign(:form, to_form(%{"quantity" => 1}))
      |> assign(:load_images?, ImageServer.up?())
      |> FlashTimed.clear_after()

    {:ok, socket_new}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index, :to_index] do
    {:noreply, apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `edit`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, apply_action(socket, act, params, ~p"/products")}
  end

  @impl true
  def handle_info(
        {CloudDbUiWeb.ProductLive.FormComponent, {:saved, product}},
        socket
      ) do
    {:noreply, stream_insert(socket, :products, product)}
  end

  @impl true
  def handle_event("order_product", params, socket) do
    {:noreply, order_product!(socket, params)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    socket_new =
      delete_product(socket, Products.get_product_with_order_count!(id))

    {:noreply, socket_new}
  end

  # An admin can see all products.
  @spec stream_products(%Socket{}) :: %Socket{}
  defp stream_products(%{assigns: %{current_user: user}} = socket)
       when user != nil and user.admin do
    stream(
      socket,
      :products,
      Products.list_products_with_type_and_order_count()
    )
  end

  # A user or a guest can see only orderable products.
  # No need for order count here.
  defp stream_products(socket) do
    stream(socket, :products, Products.list_orderable_products_with_type())
  end

  # A guest attempted to order a product.
  @spec order_product!(%Socket{}, params()) :: %Socket{}
  defp order_product!(%{assigns: %{current_user: nil}} = socket, _params) do
    socket
    |> FlashTimed.put(:error, "You must log in to order products.")
    |> redirect([to: ~p"/users/log_in"])
  end

  # An admin attempted to order a product.
  defp order_product!(
         %{assigns: %{current_user: %{admin: true}}} = socket,
         _params
       ) do
    FlashTimed.put(socket, :error, "An administrator may not order products.")
  end

  # A user attempted to order a product.
  defp order_product!(socket, %{"quantity" => quantity_delta} = params)
       when is_binary(quantity_delta) do
    case Integer.parse(quantity_delta) do
      {quantity_delta_parsed, ""} ->
        order_product!(socket, params, quantity_delta_parsed)

      _error_or_not_fully_parsed ->
        FlashTimed.put(socket, :error, "Invalid quantity.")
    end
  end

  # A user attempted to order a non-positive number of pieces of a product.
  @spec order_product!(%Socket{}, params(), integer()) :: %Socket{}
  defp order_product!(socket, _params, qty_delta) when qty_delta < 1 do
    FlashTimed.put(socket, :error, "Cannot order fewer than one piece.")
  end

  # A user attempted to order a positive number of pieces of a product.
  # `quantity_delta` can potentially be invalid (exceed the upper limit).
  defp order_product!(
         %{assigns: %{current_user: user}} = socket,
         %{"product_id" => id} = _params,
         quantity_delta
       ) do
    product = Products.get_product!(id)

    {flash_kind, message} =
      user
      |> Orders.list_orders_unpaid_with_suborder_products()
      |> case do
        [] ->
          create_order_and_suborder!(user, product, quantity_delta)

        [order | _rest] ->
          create_or_update_suborder!(order, product, quantity_delta)
      end

    FlashTimed.put(socket, flash_kind, message)
  end

  # The user has no unpaid orders, create one with a sub-order.
  # Before creating an order, validate the quantity of the sub-order.
  @spec create_order_and_suborder!(%User{}, %Product{}, pos_integer()) ::
          {atom(), [String.t()]}
  defp create_order_and_suborder!(%User{} = user, %Product{} = product, qty) do
    changeset = Orders.change_suborder_quantity(%SubOrder{}, %{quantity: qty})

    if changeset.valid? do
      {:ok, order_new} = Orders.create_order(%{user_id: user.id})
      {:ok, _sub} = Orders.create_suborder(order_new, product, qty)

      {:info, product_ordered_message(order_new, product, qty, true)}
    else
      {:error, Order.quantity_error!(changeset)}
    end
  end

  # Try to find a sub-order to update. If not found, create one.
  @spec create_or_update_suborder!(%Order{}, %Product{}, pos_integer()) ::
          {atom(), [String.t()]}
  defp create_or_update_suborder!(
         %Order{} = order,
         %Product{} = product,
         quantity_delta
       ) do
    order
    |> Order.get_suborder(product)
    |> create_or_update_suborder!(order, product, quantity_delta)
  end

  # No existing sub-order, create a new one.
  @spec create_or_update_suborder!(nil, %Order{}, %Product{}, pos_integer()) ::
          {atom(), [String.t()]}
  defp create_or_update_suborder!(
         nil,
         %Order{} = order,
         %Product{} = product,
         qty_delta
       ) do
    case Orders.create_suborder(order, product, qty_delta) do
      {:ok, _suborder_new} ->
        {:info, product_ordered_message(order, product, qty_delta, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, Order.quantity_error!(changeset)}
    end
  end

  # The sub-order exists, update it.
  @spec create_or_update_suborder!(
          %SubOrder{},
          %Order{},
          %Product{},
          pos_integer()
        ) :: {atom(), [String.t()]}
  defp create_or_update_suborder!(
         %SubOrder{} = suborder,
         %Order{} = order,
         %Product{} = product,
         quantity_delta
       ) do
    suborder
    |> Orders.update_suborder_quantity(
      %{quantity: suborder.quantity + quantity_delta}
    )
    |> case do
      {:ok, _suborder_updated} ->
        {:info, product_ordered_message(order, product, quantity_delta, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, product_ordered_message(order, product, suborder, changeset)}
    end
  end

  @spec product_ordered_message(
          %Order{},
          %Product{},
          pos_integer(),
          boolean()
        ) :: [String.t() | {:safe, list()}]
  defp product_ordered_message(
         %Order{} = order,
         %Product{} = product,
         quantity,
         true = _created?
       ) do
    s = if needs_plural_form?(quantity), do: "s"

    [
      "Created ",
      link_to_order(order),
      " and added #{quantity} piece#{s} of #{product.name} to it."
    ]
  end

  defp product_ordered_message(
         %Order{} = order,
         %Product{} = product,
         quantity,
         false = _created?
       ) do
    s = if needs_plural_form?(quantity), do: "s"

    [
      "Added #{quantity} piece#{s} of #{product.name} to ",
      link_to_order(order),
      "."
    ]
  end

  # Failed to order.
  @spec product_ordered_message(
          %Order{},
          %Product{},
          %SubOrder{},
          %Ecto.Changeset{}
        ) :: [String.t() | {:safe, list()}]
  defp product_ordered_message(
         %Order{} = order,
         %Product{} = product,
         %SubOrder{} = suborder,
         %Ecto.Changeset{} = changeset
       ) do
    s = if needs_plural_form?(suborder.quantity), do: "s"

    [
      Order.quantity_error!(changeset) <> " You already have ",
      "#{suborder.quantity} piece#{s} of #{product.name} in an unpaid ",
      link_to_order(order),
      "."
    ]
  end

  @spec link_to_order(%Order{}) :: {:safe, list()}
  defp link_to_order(%{id: id}), do: link("order ID #{id}", ~p"/orders/#{id}")
end
