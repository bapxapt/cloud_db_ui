defmodule CloudDbUiWeb.ProductTypeLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Products
  alias CloudDbUiWeb.ProductTypeLive.FormComponent
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.JavaScript
  import CloudDbUiWeb.ProductTypeLive.Actions

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
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
  def handle_info({FormComponent, {:saved, product_type}}, socket) do
    {:noreply, stream_insert(socket, :types, product_type)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, _params, true = _connected?) do
    socket
    |> stream(:types, Products.list_product_types_with_product_count())
    |> FlashTimed.clear_after()
  end

  defp prepare_socket(socket, _params, false), do: stream(socket, :types, [])
end
