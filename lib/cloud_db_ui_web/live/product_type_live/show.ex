defmodule CloudDbUiWeb.ProductTypeLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Products
  alias CloudDbUi.Products.ProductType
  alias Phoenix.LiveView.Socket
  alias CloudDbUiWeb.FlashTimed

  import CloudDbUiWeb.ProductTypeLive.Actions
  import CloudDbUiWeb.HTML
  import CloudDbUiWeb.Utilities

  @impl true
  def mount(%{"id" => type_id} = _params, _session, socket) do
    socket_new =
      socket
      |> assign_product_type_and_products!(type_id)
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
    {:noreply, apply_action(socket, action, params, ~p"/product_types/#{id}")}
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{type: type}} = socket) do
    {:noreply, delete_product_type(socket, type)}
  end

  @impl true
  def handle_info(
        {CloudDbUiWeb.ProductTypeLive.FormComponent, {:saved, type}},
        socket
      ) do
    {:noreply, assign(socket, :type, type)}
  end

  @spec assign_product_type_and_products!(%Socket{}, String.t()) :: %Socket{}
  defp assign_product_type_and_products!(socket, id) do
    type = Products.get_product_type_with_products!(id)

    socket
    # Replace the list of products with their count.
    |> assign(
      :type,
      Map.replace!(type, :products, Enum.count(type.products))
    )
    |> stream(:products, type.products)
  end

  @spec table_header(%ProductType{}) :: String.t()
  defp table_header(%ProductType{products: 0} = _type) do
    "No products with this type."
  end

  defp table_header(%ProductType{} = _type), do: "Products with this type"
end