defmodule CloudDbUiWeb.ProductTypeLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  use CloudDbUiWeb.Flop,
    schema_field_module: CloudDbUi.Products.ProductType.FlopSchemaFields,
    stream_name: :types

  alias CloudDbUiWeb.ProductTypeLive.{FormComponent, Actions}
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.JavaScript

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, Actions.apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `edit`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, Actions.apply_action(socket, act, params, ~p"/product_types")}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, filter_objects(socket, params)}
  end

  def handle_event("sort", params, socket) do
    {:noreply, sort_objects(socket, params)}
  end

  def handle_event("paginate", params, socket) do
    {:noreply, paginate_objects(socket, params)}
  end

  def handle_event("delete", %{"id" => id} = _params, socket) do
    {:noreply, delete_object(socket, id)}
  end

  @impl true
  def handle_info({FormComponent, {:saved, _type, true}}, socket) do
    {:noreply, stream_objects(socket)}
  end

  def handle_info({FormComponent, {:saved, _type, false}}, socket) do
    {:noreply, socket}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, params, true = _connected?) do
    socket
    |> stream_objects(prepare_flop(socket, params), params)
    |> FlashTimed.clear_after()
  end

  defp prepare_socket(socket, _params, false = _connected?) do
    socket
    |> assign(:meta, %Flop.Meta{})
    |> stream(:types, [])
  end
end
