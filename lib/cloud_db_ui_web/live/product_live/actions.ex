defmodule CloudDbUiWeb.ProductLive.Actions do
  # For `Phoenix.VerifiedRoutes.sigil_p()`.
  use Phoenix.VerifiedRoutes,
    endpoint: CloudDbUiWeb.Endpoint,
    router: CloudDbUiWeb.Router,
    statics: CloudDbUiWeb.static_paths()

  import Phoenix.Component
  import Phoenix.LiveView

  alias CloudDbUi.Products
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  @type params :: CloudDbUi.Type.params()

  ## `Index`.

  @spec apply_action(%Socket{}, atom(), params()) :: %Socket{}
  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:product, nil)
  end

  # An admin can create a product.
  def apply_action(
        %{assigns: %{current_user: %{admin: true}}} = socket,
        :new,
        _params
      ) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:product, %Product{product_type: %{name: nil}, orders: 0})
  end

  # A user cannot create products.
  def apply_action(socket, :new, _params) do
    socket
    |> FlashTimed.put(:error, "Only an administrator may access this page.")
    |> push_patch([to: ~p"/products"])
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

  # An admin can edit any product.
  @spec apply_action(%Socket{}, atom(), params(), String.t()) :: %Socket{}
  def apply_action(
        %{assigns: %{current_user: %{admin: true}}} = socket,
        :edit,
        %{"id" => id} = _params,
        _url_back) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, id))
    |> maybe_assign_product(id)
  end

  # A user cannot edit products.
  # Admin restrictions in the router do not help with `patch`es,
  # so put the flash manually.
  def apply_action(socket, :edit, %{"id" => _id} = _params, url_back) do
    socket
    |> FlashTimed.put(:error, "Only an administrator may access this page.")
    |> push_patch([to: url_back])
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
  def delete_product(socket, product) when not is_integer(product.orders) do
    FlashTimed.put(
      socket,
      :error,
      "Orders of product ID #{product.id} have not been preloaded."
    )
  end

  # TODO: maybe "Cannot delete a product that has PAID orders of it."
    # TODO: if this product is deleted, delete all unpaid sub-orders of this product

  # An admin cannot delete a product that has orders of it.
  def delete_product(socket, product) when product.orders > 0 do
    FlashTimed.put(
      socket,
      :error,
      "Cannot delete a product that has orders of it."
    )
  end

  # An admin can delete a product that has no orders of it.
  def delete_product(socket, product) do
    {:ok, _product_deleted} = Products.delete_product(product)

    socket
    |> FlashTimed.put(:info, "Deleted product ID #{product.id}.")
    |> apply_action_after_deletion(socket.assigns.live_action, product)
  end

  # The value of `data-confirm` for the "Delete" button.
  # Show a dialog only if all coniditons are true:
  #
  #   - the user is an admin;
  #   - the product has counted orders;
  #   - the order count does not exceed zero.
  @spec data_confirm(%User{} | nil, %Product{}) :: String.t() | nil
  def data_confirm(user, %Product{} = product) do
    cond do
      !User.admin?(user) -> nil
      !is_integer(product.orders) -> nil
      product.orders > 0 -> nil
      true -> "Are you sure?"
    end
  end

  @spec apply_action_after_deletion(%Socket{}, atom(), %Product{}) :: %Socket{}
  defp apply_action_after_deletion(socket, :index, product) do
    stream_delete(socket, :products, product)
  end

  defp apply_action_after_deletion(socket, :show, _product) do
    push_navigate(socket, [to: ~p"/products"])
  end

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

  @spec page_title(atom()) :: String.t()
  defp page_title(:index), do: "Listing products"

  defp page_title(:new), do: "New product"

  defp page_title(:show), do: "Show product"

  defp page_title(:edit), do: "Edit product"

  @spec page_title(atom(), String.t() | pos_integer()) :: String.t()
  defp page_title(action, id), do: page_title(action) <> " ID #{id}"
end
