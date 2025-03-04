defmodule CloudDbUiWeb.OrderLive.Actions do
  # For `Phoenix.VerifiedRoutes.sigil_p()`.
  use Phoenix.VerifiedRoutes,
    endpoint: CloudDbUiWeb.Endpoint,
    router: CloudDbUiWeb.Router,
    statics: CloudDbUiWeb.static_paths()

  import Phoenix.{Component, LiveView}

  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  @type params() :: CloudDbUi.Type.params()

  # TODO: is it possible to engineer a curl request for the "delete" event?

  ## `Index`.

  @spec apply_action(%Socket{}, atom(), params()) :: %Socket{}
  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:order, nil)
  end

  # An admin can create an order.
  def apply_action(
        %{assigns: %{current_user: %{admin: true}}} = socket,
        :new,
        _params
      ) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:order, %Order{suborders: [], user: nil})
  end

  # A user cannot create an order manually —
  # only via an "Order" button at `/products`.
  def apply_action(socket, :new, _params) do
    socket
    |> FlashTimed.put(:error, "Only an administrator may access this page.")
    |> push_patch([to: ~p"/orders"])
  end

  ## `Show`.

  def apply_action(socket, :show, %{"id" => id} = _params) do
    assign(socket, :page_title, page_title(socket.assigns.live_action, id))
  end

  def apply_action(socket, :redirect, %{"id" => id} = _params) do
    socket
    |> assign(:live_action, :show)
    |> push_patch([to: ~p"/orders/#{id}"])
  end

  # An admin can see the ID of a sub-order in `page_title()`.
  def apply_action(
        %{assigns: %{current_user: %{admin: true}}} = socket,
        :edit_suborder,
        %{"id" => order_id, "s_id" => suborder_id} = _params
      ) do
    order = Orders.get_order_with_full_preloads!(order_id)

    if order.paid do
      socket
      |> FlashTimed.put(:error, "Cannot edit a position of a paid order.")
      |> push_patch([to: ~p"/orders/#{order_id}"])
    else
      suborder =
        order
        |> Orders.get_suborder_from_order!(suborder_id)
        |> Map.replace!(
          :order,
          Map.replace!(order, :suborders, [])
        )

      socket
      |> assign(
        :page_title,
        page_title(socket.assigns.live_action, suborder_id)
      )
      |> assign(:suborder, suborder)
    end
  end

  # A user cannot see the ID of a sub-order in `page_title()`.
  def apply_action(
        %{assigns: %{current_user: user}} = socket,
        :edit_suborder,
        %{"id" => order_id, "s_id" => suborder_id} = _params
      ) do
    order = Orders.get_order_with_suborder_products!(order_id, user)

    if order.paid do
      socket
      |> FlashTimed.put(:error, "Cannot edit a position of a paid order.")
      |> push_patch([to: ~p"/orders/#{order_id}"])
    else
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:suborder, Orders.get_suborder_from_order!(order, suborder_id))
    end
  end

  ## Both `Index` and `Show`.

  # An admin can edit any order.
  @spec apply_action(%Socket{}, atom(), params(), String.t()) :: %Socket{}
  def apply_action(
        %{assigns: %{current_user: %{admin: true}}} = socket,
        :edit,
        %{"id" => id} = _params,
        _url_back) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, id))
    |> assign(
      :order,
      get_order(socket, id, &Orders.get_order_with_full_preloads!/1)
    )
  end

  # A user cannot directly edit orders (only via sub-orders).
  # Admin restrictions in the router do not help with `patch`es,
  # so put the flash manually.
  def apply_action(socket, :edit, %{"id" => _id} = _params, url_back) do
    socket
    |> FlashTimed.put(:error, "Only an administrator may access this page.")
    |> push_patch([to: url_back])
  end

  # An admin cannot pay for an order.
  def apply_action(
        %{assigns: %{current_user: %{admin: true}}} = socket,
        :pay,
        _params,
        url_back) do
    socket
    |> FlashTimed.put(:error, "Cannot pay for an order as an administrator.")
    |> push_patch([to: url_back])
  end

  # A user can pay only for unpaid orders (ownership gets
  # checked in `Index` or in `Show`).
  def apply_action(
        %{assigns: %{current_user: user}} = socket,
        :pay,
        %{"id" => id} = _params,
        url_back
      ) do
    order =
      get_order(
        socket,
        id,
        &Orders.get_order_with_suborder_products!(&1, user)
      )

    if order.paid_at != nil do
      socket
      |> FlashTimed.put(:error, "Cannot pay again for a paid order.")
      |> push_patch([to: url_back])
    else
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action, id))
      |> assign(:order, order)
    end
  end

  # An admin can delete any orders (no ownership check).
  @spec delete_order!(%Socket{}, %Order{}) :: %Socket{}
  def delete_order!(%{assigns: %{current_user: user}} = socket, order)
       when user.admin == true do
    delete_order(socket, order)
  end

  # A user attempts to delete an order they do not own.
  def delete_order!(%{assigns: %{current_user: user}} = _socket, order)
       when user.id != order.user_id do
    raise(%Ecto.NoResultsError{})
  end

  # A user attempts to delete their own order.
  def delete_order!(socket, order), do: delete_order(socket, order)

  # Unpaid orders can be deleted.
  @spec delete_order(%Socket{}, %Order{}) :: %Socket{}
  defp delete_order(%Socket{} = socket, %Order{paid_at: nil} = order) do
    {:ok, _} = Orders.delete_order(order)

    socket
    |> FlashTimed.put(:info, "Deleted order ID #{order.id}.")
    |> apply_action_after_deletion(socket.assigns.live_action, order)
  end

  # Paid orders cannot be deleted.
  defp delete_order(%Socket{} = socket, %Order{} = _order) do
    FlashTimed.put(socket, :error, "Cannot delete a paid order.")
  end

  @spec apply_action_after_deletion(%Socket{}, atom(), %Order{}) :: %Socket{}
  defp apply_action_after_deletion(socket, :index, order) do
    stream_delete(socket, :orders, order)
  end

  defp apply_action_after_deletion(socket, :show, _order) do
    push_navigate(socket, [to: ~p"/orders"])
  end

  # No `:order` in `socket.assigns` in case of direct access
  # to a page like `/orders/:id/edit` or `/orders/:id/show/pay`.
  @spec get_order(%Socket{}, String.t(), (String.t() -> %Order{})) :: %Order{}
  defp get_order(%{assigns: assigns} = _socket, id, fn_get) do
    if !Map.get(assigns, :order) or "#{assigns.order.id}" != id do
      fn_get.(id)
    else
      assigns.order
    end
  end

  @spec page_title(atom()) :: String.t()
  defp page_title(:index), do: "Listing orders"

  defp page_title(:new), do: "New order"

  defp page_title(:show), do: "Show order"

  defp page_title(:edit), do: "Edit order"

  defp page_title(:pay), do: "Finalise order"

  defp page_title(:edit_suborder), do: "Edit order position"

  @spec page_title(atom(), String.t() | pos_integer()) :: String.t()
  defp page_title(action, id), do: page_title(action) <> " ID #{id}"
end
