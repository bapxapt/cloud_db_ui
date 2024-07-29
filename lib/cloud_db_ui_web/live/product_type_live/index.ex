defmodule CloudDbUiWeb.ProductTypeLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Products
  alias CloudDbUiWeb.FlashTimed

  import CloudDbUiWeb.JavaScript
  import CloudDbUiWeb.ProductTypeLive.Actions

  @impl true
  def mount(_params, _session, socket) do
    socket_new =
      socket
      |> stream(:types, Products.list_product_types_with_product_count())
      |> FlashTimed.clear_after()

    {:ok, socket_new}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `edit`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, apply_action(socket, act, params, ~p"/product_types")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    socket_new =
      delete_product_type(
        socket,
        Products.get_product_type_with_product_count!(id)
      )

    {:noreply, socket_new}
  end

  @impl true
  def handle_info(
        {CloudDbUiWeb.ProductTypeLive.FormComponent, {:saved, product_type}},
        socket
      ) do
    {:noreply, stream_insert(socket, :types, product_type)}
  end
end
