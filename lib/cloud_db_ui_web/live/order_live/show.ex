defmodule CloudDbUiWeb.OrderLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUiWeb.FlashTimed
  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Orders.SubOrder
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.OrderLive.Actions
  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript

  @impl true
  def mount(%{"id" => order_id} = _params, _session, socket) do
    socket_new =
      socket
      |> assign_order_and_suborders!(order_id)
      |> FlashTimed.clear_after()

    {:ok, socket_new}
  end

  @impl true
  def handle_params(params, _uri, %{assigns: %{live_action: action}} = socket)
      when action in [:show, :redirect, :edit_suborder] do
    {:noreply, apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (actions: `:edit`, `:pay`).
  def handle_params(
        %{"id" => id} = params,
        _uri,
        %{assigns: %{live_action: action}} = socket
      ) do
    {:noreply, apply_action(socket, action, params, ~p"/orders/#{id}")}
  end

  @impl true
  def handle_event("delete", %{"s_id" => suborder_id} = _params, socket) do
    {:noreply, delete_suborder!(socket, suborder_id)}
  end

  def handle_event("delete", _params, %{assigns: %{order: order}} = socket) do
    {:noreply, delete_order!(socket, order)}
  end

  @impl true
  def handle_info({_module, {:saved, %Order{} = order}}, socket) do
    {:noreply, assign(socket, :order, order)}
  end

  def handle_info(
        {_module, {:saved, %SubOrder{} = suborder, quantity_delta}},
        socket
      ) do
    socket_new =
      socket
      |> stream_insert(:suborders, suborder)
      |> update(:order, &update_total(&1, suborder, quantity_delta))

    {:noreply, socket_new}
  end

  # An admin can delete sub-orders of any user's orders.
  @spec delete_suborder!(%Socket{}, String.t()) :: %Socket{}
  defp delete_suborder!(
         %{assigns: %{current_user: %{admin: true}}} = socket,
         id
       ) do
    delete_suborder(socket, Orders.get_suborder!(id))
  end

  # A user can delete sub-orders only of own orders.
  defp delete_suborder!(%{assigns: %{current_user: user}} = socket, id) do
    delete_suborder(socket, Orders.get_suborder!(id, user))
  end

  # An attempt to delete a non-last sub-order of an unpaid order.
  @spec delete_suborder(%Socket{}, %SubOrder{}) :: %Socket{}
  defp delete_suborder(
         %{assigns: %{order: %{paid_at: nil} = order}} = socket,
         %SubOrder{} = suborder
       ) when length(order.suborders) > 1 do
    {:ok, _} = Orders.delete_suborder(suborder)

    socket
    |> stream_delete(:suborders, suborder)
    |> update(
      :order,
      &Map.replace!(&1, :suborders, List.delete(order.suborders, suborder.id))
    )
    |> update(:order, &update_total(&1, suborder, -suborder.quantity))
    |> maybe_js_set_attribute()
  end

  # An attempt to delete the last sub-order of an unpaid order.
  defp delete_suborder(
         %{assigns: %{order: %{paid_at: nil} = order}} = socket,
         %SubOrder{} = suborder
       ) do
    {:ok, _} = Orders.delete_suborder(suborder)
    {:ok, _} = Orders.delete_order(order)

    socket
    |> FlashTimed.put(:info, "Deleted order ID #{order.id}")
    |> push_navigate([to: ~p"/orders"])
  end

  # An attempt to delete a sub-order of a paid order.
  defp delete_suborder(socket, %SubOrder{} = _suborder) do
    FlashTimed.put(socket, :error, "Cannot delete a position of a paid order.")
  end

  @spec update_total(%Order{}, %SubOrder{}, integer()) :: %Order{}
  defp update_total(order, suborder, quantity_delta) do
    total =
      order.total
      |> Decimal.add(Decimal.mult(suborder.unit_price, quantity_delta))
      |> Decimal.round(2)

    Map.replace(order, :total, total)
  end

  # Full preloads (`:user` and `:suborders`).
  @spec assign_order_and_suborders!(%Socket{}, String.t()) :: %Socket{}
  defp assign_order_and_suborders!(
         %{assigns: %{current_user: %{admin: true}}} = socket,
         order_id
       ) do
    assign_order_and_suborders(
      socket,
      Orders.get_order_with_full_preloads!(order_id)
    )
  end

  # No need to preload `:user` for a non-admin (use `@current_user`).
  defp assign_order_and_suborders!(
         %{assigns: %{current_user: user}} = socket,
         order_id
       ) do
    assign_order_and_suborders(
      socket,
      Orders.get_order_with_suborder_products!(order_id, user)
    )
  end

  @spec assign_order_and_suborders(%Socket{}, %Order{}) :: %Socket{}
  defp assign_order_and_suborders(%Socket{} = socket, %Order{} = order) do
    socket
    # Convert the list of sub-orders into a list of their IDs.
    |> assign(
      :order,
      Map.replace!(order, :suborders, Enum.map(order.suborders, &(&1.id)))
    )
    |> stream(:suborders, sort_structures(order.suborders, :inserted_at))
  end

  # The text in a deletion confirmation dialog (`data-confirm` attribute).
  @spec data_confirm(%Order{}) :: String.t()
  defp data_confirm(%Order{suborders: subs} = order) when is_list(subs) do
    cond do
      order.paid -> ""
      length(subs) <= 1 -> "This will delete the whole order. Are you sure?"
      true -> "Are you sure?"
    end
  end

  # If only one sub-order left after deletion of an other sub-orders,
  # change the `data-confirm` attribute of the "Delete" link.
  @spec maybe_js_set_attribute(%Socket{}) :: %Socket{}
  defp maybe_js_set_attribute(%{assigns: %{order: order}} = socket)
       when length(order.suborders) <= 1 do
    js_set_attribute(
      socket,
      "[id^=\"suborder-delete-\"]",
      %{"data-confirm" => data_confirm(order)}
    )
  end

  defp maybe_js_set_attribute(%Socket{} = socket), do: socket
end
