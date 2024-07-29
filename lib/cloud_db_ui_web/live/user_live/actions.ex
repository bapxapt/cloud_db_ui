defmodule CloudDbUiWeb.UserLive.Actions do
  # For `Phoenix.VerifiedRoutes.sigil_p()`.
  use Phoenix.VerifiedRoutes,
    endpoint: CloudDbUiWeb.Endpoint,
    router: CloudDbUiWeb.Router,
    statics: CloudDbUiWeb.static_paths()

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import Phoenix.{Component, LiveView}

  @type params :: CloudDbUi.Type.params()

  ## `Index`.

  @spec apply_action(%Socket{}, atom(), params()) :: %Socket{}
  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:user, nil)
  end

  def apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:user, %User{orders: 0})
  end

  ## `Show`.

  def apply_action(socket, :show, %{"id" => id} = _params) do
    assign(socket, :page_title, page_title(socket.assigns.live_action, id))
  end

  def apply_action(socket, :redirect, %{"id" => id} = _params) do
    socket
    |> assign(:live_action, :show)
    |> push_patch([to: ~p"/users/#{id}"])
  end

  ## Both `Index` and `Show`.

  @spec apply_action(%Socket{}, atom(), params(), String.t()) :: %Socket{}
  def apply_action(socket, :edit, %{"id" => id} = _params, url_back) do
    user = get_user(socket, id, &Accounts.get_user_with_order_count!/1)

    cond do
      user.id == socket.assigns.current_user.id ->
        socket
        |> FlashTimed.put(:error, "Cannot edit self.")
        |> push_patch([to: url_back])

      user.admin ->
        socket
        |> FlashTimed.put(:error, "Cannot edit an administrator.")
        |> push_patch([to: url_back])

      true ->
        socket
        |> assign(:page_title, page_title(socket.assigns.live_action, id))
        |> assign(:user, user)
    end
  end

  @spec delete_user(%Socket{}, %User{}) :: %Socket{}
  def delete_user(%Socket{} = socket, %User{id: id} = _user)
      when socket.assigns.current_user.id == id do
    FlashTimed.put(socket, :error, "Cannot delete self.")
  end

  def delete_user(%Socket{} = socket, %User{admin: true} = _user) do
    FlashTimed.put(socket, :error, "Cannot delete an administrator.")
  end

  # The `:paid_orders` virtual field has not been filled properly.
  def delete_user(%Socket{} = socket, %User{paid_orders: nil} = _user) do
    FlashTimed.put(socket, :error, user_deletion_error_message())
  end

  # An admin can delete non-admin users that have zero balance and
  # no paid orders.
  def delete_user(%Socket{} = socket, %User{} = user) do
    if user.paid_orders > 0 or Decimal.compare(user.balance, 0) == :gt do
      FlashTimed.put(socket, :error, user_deletion_error_message())
    else
      {:ok, _} = Accounts.delete_user(user)

      socket
      |> FlashTimed.put(
        :info,
        "Deleted user ID #{user.id} and any unpaid orders owned by this user."
      )
      |> apply_action_after_deletion(socket.assigns.live_action, user)
    end
  end

  @spec apply_action_after_deletion(%Socket{}, atom(), %User{}) ::
          %Socket{}
  defp apply_action_after_deletion(socket, :index, user) do
    stream_delete(socket, :users, user)
  end

  defp apply_action_after_deletion(socket, :show, _user) do
    push_navigate(socket, [to: ~p"/users"])
  end

  @spec user_deletion_error_message() :: String.t()
  defp user_deletion_error_message() do
    "Cannot delete a user that owns any paid orders or has non-zero balance."
  end

  # No `:user` in `socket.assigns` in case of direct access
  # to a page like `/users/:id/edit`.
  @spec get_user(%Socket{}, String.t(), (String.t() -> %User{})) :: %User{}
  defp get_user(%{assigns: assigns} = _socket, id, fn_get) do
    cond do
      Map.get(assigns, :user) && "#{assigns.user.id}" == id -> assigns.user
      "#{assigns.current_user.id}" == id -> assigns.current_user
      true -> fn_get.(id)
    end
  end

  @spec page_title(atom()) :: String.t()
  defp page_title(:index), do: "Listing users"

  defp page_title(:new), do: "New user"

  defp page_title(:show), do: "Show user"

  defp page_title(:edit), do: "Edit user"

  @spec page_title(atom(), String.t() | pos_integer()) :: String.t()
  defp page_title(action, id), do: page_title(action) <> " ID #{id}"
end
