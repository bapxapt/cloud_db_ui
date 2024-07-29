defmodule CloudDbUiWeb.ProductLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUiWeb.ProductLive.FormComponent
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.HTML
  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript
  import CloudDbUiWeb.ProductLive.Actions

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
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
  def handle_info({FormComponent, {:saved, product}}, socket) do
    {:noreply, stream_insert(socket, :products, product)}
  end

  @impl true
  def handle_event("order", %{"sub_order" => suborder_params}, socket) do
    {:noreply, order_product!(socket, suborder_params)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    socket_new =
      delete_product(socket, Products.get_product_with_order_count!(id))

    {:noreply, socket_new}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, _params, true = _connected?) do
    socket
    |> stream_products()
    |> assign(:form, to_form(%{"quantity" => 1}))
    |> assign(:load_images?, CloudDbUiWeb.ImageServer.up?())
    |> FlashTimed.clear_after()
  end

  defp prepare_socket(socket, _prms, false), do: stream(socket, :products, [])

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
end
