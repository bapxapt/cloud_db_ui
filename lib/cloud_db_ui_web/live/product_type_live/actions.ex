defmodule CloudDbUiWeb.ProductTypeLive.Actions do
  # For `Phoenix.VerifiedRoutes.sigil_p()`.
  use Phoenix.VerifiedRoutes,
    endpoint: CloudDbUiWeb.Endpoint,
    router: CloudDbUiWeb.Router,
    statics: CloudDbUiWeb.static_paths()

  alias CloudDbUi.Products
  alias CloudDbUi.Products.ProductType
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import Phoenix.{Component, LiveView}

  @type params :: CloudDbUi.Type.params()

  ## `Index`.

  @spec apply_action(%Socket{}, atom(), params()) :: %Socket{}
  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:type, nil)
  end

  def apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:type, %ProductType{products: 0, name: ""})
  end

  ## `Show`.

  def apply_action(socket, :show, %{"id" => id} = _params) do
    assign(socket, :page_title, page_title(socket.assigns.live_action, id))
  end

  def apply_action(socket, :redirect, %{"id" => id} = _params) do
    socket
    |> assign(:live_action, :show)
    |> push_patch([to: ~p"/product_types/#{id}"])
  end

  ## Both `Index` and `Show`.

  @spec apply_action(%Socket{}, atom(), params(), String.t()) :: %Socket{}
  def apply_action(socket, :edit, %{"id" => id} = _params, _url_back) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, id))
    |> maybe_assign_product_type(id)
  end

  @spec delete_product_type(%Socket{}, %ProductType{}) :: %Socket{}
  def delete_product_type(socket, type) when not is_integer(type.products) do
    FlashTimed.put(
      socket,
      :error,
      "Products of product type ID #{type.id} have not been preloaded."
    )
  end

  def delete_product_type(socket, type) when type.products > 0 do
    FlashTimed.put(
      socket,
      :error,
      "Cannot delete a product type that is assigned to a product."
    )
  end

  # Deleting a product type that is not assigned to any products.
  def delete_product_type(socket, type) do
    {:ok, _deleted_type} = Products.delete_product_type(type)

    socket
    |> FlashTimed.put(:info, "Deleted product type ID #{type.id}.")
    |> apply_action_after_deletion(socket.assigns.live_action, type)
  end

  @spec apply_action_after_deletion(%Socket{}, atom(), %ProductType{}) ::
          %Socket{}
  defp apply_action_after_deletion(socket, :index, type) do
    stream_delete(socket, :types, type)
  end

  defp apply_action_after_deletion(socket, :show, _type) do
    push_navigate(socket, [to: ~p"/product_types"])
  end

  # No `:type` in `socket.assigns` in case of direct access
  # to a page like `/product_types/:id/edit`.
  @spec maybe_assign_product_type(%Socket{}, String.t()) :: %Socket{}
  defp maybe_assign_product_type(%{assigns: assigns} = socket, id) do
    if !Map.get(assigns, :type) or "#{assigns.type.id}" != id do
      assign(socket, :type, Products.get_product_type_with_product_count!(id))
    else
      socket
    end
  end

  @spec page_title(atom()) :: String.t()
  defp page_title(:index), do: "Listing product types"

  defp page_title(:new), do: "New product type"

  defp page_title(:show), do: "Show product type"

  defp page_title(:edit), do: "Edit product type"

  @spec page_title(atom(), String.t() | pos_integer()) :: String.t()
  defp page_title(action, id), do: page_title(action) <> " ID #{id}"
end
