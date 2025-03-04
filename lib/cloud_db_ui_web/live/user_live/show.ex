defmodule CloudDbUiWeb.UserLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  import CloudDbUiWeb.UserLive.Actions
  import CloudDbUiWeb.Utilities

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders.Order
  alias CloudDbUiWeb.UserLive.FormComponent
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  @type params() :: CloudDbUi.Type.params()

  # TODO: the app layout does not get rendered if a 404 exception happens during a connected mount()
    # TODO: this does not happen during a disconnected mount()

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
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
    {:noreply, apply_action(socket, action, params, ~p"/users/#{id}")}
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{user: user}} = socket) do
    {:noreply, delete_user(socket, user)}
  end

  @impl true
  def handle_info({FormComponent, {:saved, user, _refilter?}}, socket) do
    {:noreply, assign(socket, :user, user)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, %{"id" => user_id}, true = _connected?) do
    socket
    |> assign_user_and_orders!(user_id)
    |> FlashTimed.clear_after()
  end

  defp prepare_socket(socket, %{"id" => _} = _params, false = _connected?) do
    socket
    |> assign(:user, nil)
    |> stream(:orders, [])
  end

  # Converts the list of orders into a list of their IDs.
  @spec assign_user_and_orders!(%Socket{}, String.t()) :: %Socket{}
  defp assign_user_and_orders!(socket, id) do
    user = get_user(socket, id)

    socket
    |> assign(
      :user,
      Map.replace!(user, :orders, Enum.map(user.orders, &(&1.id)))
    )
    |> stream(:orders, sort_structures(user.orders, :paid_at))
  end

  @spec get_user(%Socket{}, String.t()) :: %User{}
  defp get_user(%{assigns: %{current_user: user}} = _socket, id) do
    cond do
      id == "#{user.id}" -> Map.replace!(user, :orders, [])
      true -> Accounts.get_user_with_order_suborder_products!(id)
    end
  end

  @spec table_header(%User{} | nil) :: String.t()
  defp table_header(%User{orders: orders}) when not is_list(orders) do
    "Owns #{orders} orders."
  end

  defp table_header(%User{orders: []}), do: "The user owns no orders."

  # The user is `nil`, or the vlaue of `:order` is not an empty list.
  defp table_header(_user), do: "Orders owned by the user"
end
