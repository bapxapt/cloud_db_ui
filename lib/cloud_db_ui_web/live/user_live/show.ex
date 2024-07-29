defmodule CloudDbUiWeb.UserLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders.Order
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.UserLive.Actions
  import CloudDbUiWeb.Utilities

  @impl true
  def mount(%{"id" => user_id} = _params, _session, socket) do
    socket_new =
      socket
      |> assign_user_and_orders!(user_id)
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
    {:noreply, apply_action(socket, action, params, ~p"/users/#{id}")}
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{user: user}} = socket) do
    {:noreply, delete_user(socket, user)}
  end

  @impl true
  def handle_info(
        {CloudDbUiWeb.UserLive.FormComponent, {:saved, user}},
        socket
      ) do
    {:noreply, assign(socket, :user, user)}
  end

  @spec assign_user_and_orders!(%Socket{}, String.t()) :: %Socket{}
  defp assign_user_and_orders!(socket, id) do
    user = get_user(socket, id)

    socket
    # Convert the list of orders into a list of their IDs.
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

  @spec table_header(%User{}) :: String.t()
  defp table_header(%User{orders: orders}) when not is_list(orders) do
    "Owns #{orders} orders."
  end

  defp table_header(%User{orders: []}), do: "The user owns no orders."

  defp table_header(%User{orders: _}), do: "Orders owned by the user"
end
