defmodule CloudDbUiWeb.ProductLive.Actions do
  # For `Phoenix.VerifiedRoutes.sigil_p()`.
  use Phoenix.VerifiedRoutes,
    endpoint: CloudDbUiWeb.Endpoint,
    router: CloudDbUiWeb.Router,
    statics: CloudDbUiWeb.static_paths()

  import CloudDbUiWeb.{HTML, Utilities}
  import Phoenix.{Component, LiveView}

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.{Products, Orders}
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket
  alias Ecto.Changeset

  @type params :: CloudDbUi.Type.params()

  ## `Index`.

  @spec apply_action(%Socket{}, atom(), params()) :: %Socket{}
  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:product, nil)
  end

  # A not-logged-in guest cannot create a product.
  def apply_action(%{assigns: %{current_user: nil}} = socket, :new, _params) do
    socket
    |> FlashTimed.put(:error, "You must log in to access this page.")
    |> redirect([to: ~p"/log_in"])
  end

  # A non-administrator user cannot create a product.
  def apply_action(%{assigns: %{current_user: user}} = socket, :new, _params)
      when not user.admin do
    socket
    |> FlashTimed.put(:error, "Only an administrator may access this page.")
    |> push_patch([to: ~p"/products"])
  end

  # An admin can create a product.
  def apply_action(%{assigns: %{current_user: _admin}} = socket, :new, _) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:product, %Product{orders: 0})
  end

  def apply_action(socket, :to_index, _params) do
    socket
    |> assign(:live_action, :index)
    |> push_patch([to: ~p"/products"])
  end

  ## `Show`.

  def apply_action(socket, :show, %{"id" => id} = _params) do
    assign(socket, :page_title, page_title(socket.assigns.live_action, id))
  end

  def apply_action(socket, :redirect, %{"id" => id} = _params) do
    socket
    |> assign(:live_action, :show)
    |> push_patch([to: ~p"/products/#{id}"])
  end

  ## Both `Index` and `Show`.

  # A not-logged-in guest cannot edit a product.
  def apply_action(%{assigns: %{current_user: nil}} = socket, :edit, _, _) do
    socket
    |> FlashTimed.put(:error, "You must log in to access this page.")
    |> redirect([to: ~p"/log_in"])
  end

  # A user cannot edit a product.
  def apply_action(%{assigns: %{current_user: user}} = socket, :edit, _, url)
      when not user.admin do
    socket
    |> FlashTimed.put(:error, "Only an administrator may access this page.")
    |> push_patch([to: url])
  end

  # An admin can edit a product.
  @spec apply_action(%Socket{}, atom(), params(), String.t()) :: %Socket{}
  def apply_action(socket, :edit, %{"id" => id} = _params, _url_back) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, id))
    |> maybe_assign_product(id)
  end

  # A guest attempted to order a product.
  @spec order_product!(%Socket{}, params()) :: %Socket{}
  def order_product!(%{assigns: %{current_user: nil}} = socket, _so_params) do
    socket
    |> FlashTimed.put(:error, "You must log in to order products.")
    |> redirect([to: ~p"/log_in"])
  end

  # An admin attempted to order a product.
  def order_product!(
         %{assigns: %{current_user: %{admin: true}}} = socket,
         _suborder_params
       ) do
    FlashTimed.put(socket, :error, "An administrator may not order products.")
  end

  # A user attempted to order a product.
  def order_product!(socket, %{"product_id" => id, "quantity" => qty_raw}) do
    case Integer.parse(qty_raw) do
      {qty, ""} -> order_product!(socket, id, qty)
      _not_fully_parsed -> FlashTimed.put(socket, :error, "Invalid quantity.")
    end
  end

  # A user or a guest cannot delete products.
  def delete_product(%{assigns: %{current_user: user}} = socket, _product)
      when user == nil or user.admin == false do
    FlashTimed.put(
      socket,
      :error,
      "Only an administrator may delete products."
    )
  end

  @spec delete_product(%Socket{}, %Product{}) :: %Socket{}
  def delete_product(socket, prod) when not is_integer(prod.paid_orders) do
    FlashTimed.put(
      socket,
      :error,
      "Paid orders of product ID #{prod.id} have not been preloaded."
    )
  end

  # An admin cannot delete a product that has orders of it.
  def delete_product(socket, product) when product.paid_orders > 0 do
    FlashTimed.put(
      socket,
      :error,
      "Cannot delete a product, paid orders of which exist."
    )
  end

  # An admin can delete a product that has no orders of it.
  def delete_product(socket, product) do
    {:ok, _product_deleted} = Products.delete_product(product)

    socket
    |> FlashTimed.put(:info, "Deleted product ID #{product.id}.")
    |> apply_action_after_deletion(socket.assigns.live_action, product)
  end

  @spec apply_action_after_deletion(%Socket{}, atom(), %Product{}) :: %Socket{}
  defp apply_action_after_deletion(socket, :index, product) do
    stream_delete(socket, :products, product)
  end

  defp apply_action_after_deletion(socket, :show, _product) do
    push_navigate(socket, [to: ~p"/products"])
  end

  # A user attempted to order a non-positive number of pieces of a product.
  @spec order_product!(%Socket{}, String.t(), integer()) :: %Socket{}
  defp order_product!(socket, _id, qty) when qty < 1 do
    FlashTimed.put(socket, :error, "Cannot order fewer than one piece.")
  end

  # A user attempted to order a positive number of pieces of a product.
  # `qty` can potentially be invalid (exceed the upper limit).
  defp order_product!(%{assigns: %{current_user: user}} = socket, id, qty) do
    product = Products.get_product!(id)

    {flash_kind, message} =
      user
      |> Orders.list_orders_unpaid_with_suborder_products()
      |> case do
        [] -> create_order_and_suborder!(user, product, qty)
        [order | _rest] -> create_or_update_suborder!(order, product, qty)
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
      {:ok, order_new} = Orders.create_order(%{user_id: user.id}, user)
      {:ok, _sub} = Orders.create_suborder(order_new, product, qty)

      {:info, product_ordered_message(order_new, product, qty, true)}
    else
      {:error, Order.quantity_error!(changeset)}
    end
  end

  # Try to find a sub-order to update, pass it further.
  @spec create_or_update_suborder!(%Order{}, %Product{}, pos_integer()) ::
          {atom(), [String.t()]}
  defp create_or_update_suborder!(order, product, quantity_delta) do
    order
    |> Order.get_suborder(product)
    |> create_or_update_suborder!(order, product, quantity_delta)
  end

  # No existing sub-order, create a new one.
  @spec create_or_update_suborder!(
          %SubOrder{} | nil,
          %Order{},
          %Product{},
          pos_integer()
        ) :: {:info | :error, [String.t()]}
  defp create_or_update_suborder!(nil, order, product, qty_delta) do
    case Orders.create_suborder(order, product, qty_delta) do
      {:ok, _suborder_new} ->
        {:info, product_ordered_message(order, product, qty_delta, false)}

      {:error, %Changeset{} = changeset} ->
        {:error, Order.quantity_error!(changeset)}
    end
  end

  # The sub-order exists, update it.
  defp create_or_update_suborder!(suborder, order, product, qty_delta) do
    suborder
    |> Orders.update_suborder_quantity(
      %{quantity: suborder.quantity + qty_delta}
    )
    |> case do
      {:ok, _suborder_updated} ->
        {:info, product_ordered_message(order, product, qty_delta, false)}

      {:error, %Changeset{} = changeset} ->
        {:error, product_ordered_message(order, product, suborder, changeset)}
    end
  end

  # Ordered successfully (created a new unpaid order).
  @spec product_ordered_message(
          %Order{},
          %Product{},
          pos_integer(),
          boolean()
        ) :: [String.t() | {:safe, list()}]
  defp product_ordered_message(order, product, quantity, true = _created?) do
    s = if needs_plural_form?(quantity), do: "s"

    [
      "Created ",
      link_to_order(order),
      " and added #{quantity} piece#{s} of #{product.name} to it."
    ]
  end

  # Ordered successfully (updated an existing unpaid order).
  defp product_ordered_message(order, product, quantity, false = _created?) do
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
          %Changeset{}
        ) :: [String.t() | {:safe, list()}]
  defp product_ordered_message(order, product, suborder, %Changeset{} = set) do
    s = if needs_plural_form?(suborder.quantity), do: "s"

    [
      Order.quantity_error!(set) <> " You already have ",
      "#{suborder.quantity} piece#{s} of #{product.name} in an unpaid ",
      link_to_order(order),
      "."
    ]
  end

  @spec link_to_order(%Order{}) :: {:safe, list()}
  defp link_to_order(%{id: id}), do: link("order ID #{id}", ~p"/orders/#{id}")

  # No `:product` in `socket.assigns` in case of direct access
  # to a page like `/products/:id/edit`.
  @spec maybe_assign_product(%Socket{}, String.t()) :: %Socket{}
  defp maybe_assign_product(%{assigns: assigns} = socket, id) do
    if !Map.get(assigns, :product) or "#{assigns.product.id}" != id do
      assign(
        socket,
        :product,
        Products.get_product_with_type_and_order_count!(id)
      )
    else
      socket
    end
  end

  # The value of `data-confirm` for the "Delete" button.
  # Show a dialog only if all coniditons are true:
  #
  #   - the user is an admin;
  #   - the product has counted paid orders;
  #   - the paid order count does not exceed zero.
  @spec data_confirm(%User{} | nil, %Product{}) :: String.t() | nil
  def data_confirm(user, %Product{} = product) do
    if User.admin?(user) and product.paid_orders == 0, do: "Are you sure?"
  end

  @spec page_title(atom()) :: String.t()
  defp page_title(:index), do: "Listing products"

  defp page_title(:new), do: "New product"

  defp page_title(:show), do: "Show product"

  defp page_title(:edit), do: "Edit product"

  @spec page_title(atom(), String.t() | pos_integer()) :: String.t()
  defp page_title(action, id), do: page_title(action) <> " ID #{id}"
end
