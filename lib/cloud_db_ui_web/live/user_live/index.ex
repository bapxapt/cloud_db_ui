defmodule CloudDbUiWeb.UserLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  use CloudDbUiWeb.Flop,
    schema_field_module: CloudDbUi.Accounts.User.FlopSchemaFields,
    stream_name: :users

  import CloudDbUiWeb.JavaScript

  alias CloudDbUiWeb.UserLive.{FormComponent, Actions}
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  @type params() :: CloudDbUi.Type.params()

  # TODO: remove
  # TODO: ?filters[0][field]=email_trimmed&filters[0][op]=ilike&filters[0][value]=&filters[1][field]=confirmed_at&filters[1][op]=not_empty&filters[1][value]=&filters[2][field]=confirmed_at&filters[2][op]=>%3D&filters[2][value]=99999-12-11T11:11&filters[3][field]=confirmed_at&filters[3][op]=<%3D&filters[3][value]=&filters[4][field]=inserted_at&filters[4][op]=>%3D&filters[4][value]=&filters[5][field]=inserted_at&filters[5][op]=<%3D&filters[5][value]=&filters[6][field]=balance_trimmed&filters[6][op]=>%3D&filters[6][value]=%20 10.00%20%20%20%20%20 &filters[7][field]=balance_trimmed&filters[7][op]=<%3D&filters[7][value]=%20 9.00%20 &filters[8][field]=active&filters[8][op]=%3D%3D&filters[8][value]=&filters[9][field]=admin&filters[9][op]=%3D%3D&filters[9][value]=&order_by[]=confirmed_at&order_by[]=balance&order_by[]=id&order_directions[]=asc&order_directions[]=asc&order_directions[]=asc&_target[]=filters&_target[]=99&_target[]=f

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, Actions.apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `:edit`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, Actions.apply_action(socket, act, params, ~p"/users")}
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
  def handle_info({FormComponent, {:saved, _user, true}}, socket) do
    {:noreply, stream_objects(socket)}
  end

  def handle_info({FormComponent, {:saved, _user, false}}, socket) do
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
    |> stream(:users, [])
  end

  # TODO: remove?

  #@spec delete_user_by_id!(%Socket{}, String.t()) :: %Socket{}
  #defp delete_user_by_id!(socket, id) do
  #  case "#{socket.assigns.current_user.id}" == id do
  #    true -> FlashTimed.put(socket, :error, "Cannot delete self.")
  #    false -> delete_user(socket, Accounts.get_user_with_order_count!(id))
  #  end
  #  |> case do
  #    %{assigns: %{flash: %{"error" => _title}}} = with_error -> with_error
  #    without_error -> stream_objects(without_error)
  #  end
  #end
end
