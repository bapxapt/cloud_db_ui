defmodule CloudDbUiWeb.OrderLive.Show do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUiWeb.FlashTimed
  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.OrderLive.Actions
  import CloudDbUiWeb.{Utilities, JavaScript}

  @type params() :: CloudDbUi.Type.params()

  # TODO: why can't we use connected?() with prepare_socket() in Show?

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
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
  def handle_info({_module, {:saved, %Order{} = order, _refilter?}}, socket) do
    {:noreply, assign(socket, :order, order)}
  end

  # `:order_id` has not been changed.
  def handle_info(
        {_module, {:saved, %SubOrder{} = suborder}},
        %{assigns: %{suborder: suborder_old}} = socket
      ) when suborder.order_id == suborder_old.order_id do
    socket_new =
      socket
      |> stream_insert(:suborders, suborder)
      |> update_order_total(
        suborder_old,
        suborder.quantity - suborder_old.quantity,
        Decimal.sub(suborder.unit_price, suborder_old.unit_price)
      )

    {:noreply, socket_new}
  end

  # `:order_id` has been changed, the sub-order has been assigned
  # to an other order.
  def handle_info(
        {_module, {:saved, %SubOrder{} = suborder}},
        %{assigns: %{suborder: suborder_old}} = socket
      ) do
    socket_new =
      socket
      |> stream_delete(:suborders, suborder)
      |> delete_suborder_id(suborder)
      |> update_order_total(suborder_old, -suborder_old.quantity)

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

  # An attempt to delete a sub-order of a paid order.
  defp delete_suborder(socket, _so) when socket.assigns.order.paid_at != nil do
    FlashTimed.put(socket, :error, "Cannot delete a position of a paid order.")
  end

  # An admin attempts to delete any sub-order (even a last one)
  # of an unpaid order.
  defp delete_suborder(
         %{assigns: %{current_user: %{admin: true}}} = socket,
         suborder
       ) do
    socket
    |> delete_suborder_without_deleting_order(suborder)
    |> FlashTimed.put(:info, "Deleted order position ID #{suborder.id}.")
  end

  # A user attempts to delete a non-last sub-order of an unpaid order.
  defp delete_suborder(socket, suborder)
       when length(socket.assigns.order.suborders) > 1 do
    socket
    |> delete_suborder_without_deleting_order(suborder)
    |> FlashTimed.put(:info, "Deleted an order position.")
  end

  # A user attempts to delete the last sub-order of an unpaid order.
  defp delete_suborder(socket, suborder) do
    {:ok, _} = Orders.delete_suborder(suborder, socket.assigns.order)
    {:ok, _} = Orders.delete_order(socket.assigns.order)

    socket
    |> FlashTimed.put(:info, "Deleted order ID #{socket.assigns.order.id}.")
    |> push_navigate([to: ~p"/orders"])
  end

  @spec delete_suborder_without_deleting_order(%Socket{}, %SubOrder{}) ::
          %Socket{}
  defp delete_suborder_without_deleting_order(socket, suborder) do
    {:ok, _} = Orders.delete_suborder(suborder, socket.assigns.order)

    socket
    |> stream_delete(:suborders, suborder)
    |> delete_suborder_id(suborder)
    |> update_order_total(suborder, -suborder.quantity)
    |> maybe_js_set_attribute()
  end

  @spec update_order_total(%Socket{}, %SubOrder{}, integer(), %Decimal{}) ::
          %Socket{}
  defp update_order_total(
         %Socket{} = socket,
         %SubOrder{} = suborder,
         qty_delta,
         cost_delta \\ Decimal.new("0")
       ) do
    update(
      socket,
      :order,
      &update_total(&1, suborder, qty_delta, cost_delta)
    )
  end

  @spec update_total(%Order{}, %SubOrder{}, integer(), %Decimal{}) :: %Order{}
  defp update_total(%Order{} = order, suborder, qty_delta, cost_delta) do
    total_new =
      order.total
      |> Decimal.add(Decimal.mult(suborder.unit_price, qty_delta))
      |> Decimal.add(
        Decimal.mult(cost_delta, suborder.quantity + qty_delta)
      )
      |> Decimal.round(2)

    Map.replace(order, :total, total_new)
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, %{"id" => order_id} = _params) do
    socket
    |> assign_order_and_suborders!(order_id)
    |> FlashTimed.clear_after()
  end

  # With full preloads (`:user` and `:suborders`).
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

  # Converts the list of sub-orders into a list of their IDs.
  @spec assign_order_and_suborders(%Socket{}, %Order{}) :: %Socket{}
  defp assign_order_and_suborders(%Socket{} = socket, %Order{} = order) do
    socket
    |> assign(
      :order,
      Map.replace!(order, :suborders, Enum.map(order.suborders, &(&1.id)))
    )
    |> stream(:suborders, sort_structures(order.suborders, :inserted_at))
  end

  @spec data_confirm_order(%Order{}) :: String.t()
  defp data_confirm_order(%Order{paid_at: nil} = _order) do
    "This will delete the whole order. Are you sure?"
  end

  defp data_confirm_order(%Order{} = _order), do: ""

  # The text in a deletion confirmation dialog (the `data-confirm=""`
  # attribute) when attempting to delete a sub-order.
  @spec data_confirm_suborder(%Order{}, boolean()) :: String.t()
  defp data_confirm_suborder(%Order{} = order, admin?) do
    cond do
      order.paid_at -> ""
      admin? or length(order.suborders) > 1 -> "Are you sure?"
      true -> "This will delete the whole order. Are you sure?"
    end
  end

  # Delete suborder ID from `socket.assigns.suborders` (which is a list
  # of suborder IDs).
  @spec delete_suborder_id(%Socket{}, %SubOrder{}) :: %Socket{}
  defp delete_suborder_id(socket, suborder) do
    update(
      socket,
      :order,
      &Map.replace!(&1, :suborders, List.delete(&1.suborders, suborder.id))
    )
  end

  # Only one sub-order left after deletion of an other sub-order,
  # change the `data-confirm` attribute of the "Delete" link.
  @spec maybe_js_set_attribute(%Socket{}) :: %Socket{}
  defp maybe_js_set_attribute(%{assigns: %{order: order} = assigns} = socket)
       when not assigns.current_user.admin and length(order.suborders) == 1 do
    js_set_attribute(
      socket,
      "[id^=\"suborder-delete-\"]",
      %{"data-confirm" => data_confirm_suborder(order, false)}
    )
  end

  # More than one sub-order left after deletion of an other sub-order
  # and/or the `:current_user` is an administrator.
  defp maybe_js_set_attribute(%{assigns: %{order: _}} = socket), do: socket
end
