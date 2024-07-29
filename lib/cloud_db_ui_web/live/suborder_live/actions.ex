defmodule CloudDbUiWeb.SubOrderLive.Actions do
  # For `Phoenix.VerifiedRoutes.sigil_p()`.
  use Phoenix.VerifiedRoutes,
    endpoint: CloudDbUiWeb.Endpoint,
    router: CloudDbUiWeb.Router,
    statics: CloudDbUiWeb.static_paths()

  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import Phoenix.{Component, LiveView}

  @type params :: CloudDbUi.Type.params()

  # TODO: A user attempts to delete a sub-order of an order
  # TODO: they do not own.
    # TODO: an example is CloudDbUiWeb.OrderLive.Actions.delete_order!()

  ## `Index`.

  @spec apply_action(%Socket{}, atom(), params()) :: %Socket{}
  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:suborder, nil)
  end

  def apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:suborder, %SubOrder{product: nil, order: nil, subtotal: "0"})
  end

  ## `Show`.

  def apply_action(socket, :show, %{"id" => id} = _params) do
    assign(socket, :page_title, page_title(socket.assigns.live_action, id))
  end

  def apply_action(socket, :redirect, %{"id" => id} = _params) do
    socket
    |> assign(:live_action, :show)
    |> push_patch(to: ~p"/sub-orders/#{id}")
  end

  ## Both `Index` and `Show`.

  @spec apply_action(%Socket{}, atom(), params(), String.t()) :: %Socket{}
  def apply_action(socket, :edit, %{"id" => id} = _params, url_back) do
    suborder =
      get_suborder(
        socket,
        id,
        &Orders.get_suborder_with_product_and_order_user!/1
      )

    if suborder.order.paid_at do
      socket
      |> FlashTimed.put(:error, "Cannot edit a position of a paid order.")
      |> push_patch([to: url_back])
    else
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action, id))
      |> assign(:suborder, suborder)
    end
  end

  @spec delete_suborder(%Socket{}, %SubOrder{}) :: %Socket{}
  def delete_suborder(socket, %{order: %Order{paid_at: nil}} = suborder) do
    {:ok, _deleted_suborder} = Orders.delete_suborder(suborder, suborder.order)

    socket
    |> FlashTimed.put(:info, "Deleted order position ID #{suborder.id}.")
    |> apply_action_after_deletion(socket.assigns.live_action, suborder)
  end

  def delete_suborder(socket, %{order: %Order{}} = _suborder) do
    FlashTimed.put(socket, :error, "Cannot delete a position of a paid order.")
  end

  def delete_suborder(socket, suborder) do
    FlashTimed.put(
      socket,
      :error,
      "Order of order position ID #{suborder.id} has not been preloaded."
    )
  end

  @spec apply_action_after_deletion(%Socket{}, atom(), %SubOrder{}) ::
          %Socket{}
  defp apply_action_after_deletion(socket, :index, suborder) do
    stream_delete(socket, :suborders, suborder)
  end

  defp apply_action_after_deletion(socket, :show, _suborder) do
    push_navigate(socket, [to: ~p"/sub-orders"])
  end

  # No `:order` in `socket.assigns` in case of direct access
  # to a page like `/sub-orders/:id/edit`.
  @spec get_suborder(%Socket{}, String.t(), (String.t() -> %SubOrder{})) ::
          %SubOrder{}
  defp get_suborder(%{assigns: assigns} = _socket, id, fn_get) do
    if !Map.get(assigns, :suborder) or "#{assigns.suborder.id}" != id do
      fn_get.(id)
    else
      assigns.suborder
    end
  end

  @spec page_title(atom()) :: String.t()
  defp page_title(:index), do: "Listing order positions"

  defp page_title(:new), do: "New order position"

  defp page_title(:show), do: "Show order position"

  defp page_title(:edit), do: "Edit order position"

  @spec page_title(atom(), String.t() | pos_integer()) :: String.t()
  defp page_title(action, id), do: page_title(action) <> " ID #{id}"
end
