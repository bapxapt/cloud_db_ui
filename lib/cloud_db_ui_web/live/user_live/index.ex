defmodule CloudDbUiWeb.UserLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript
  import CloudDbUiWeb.UserLive.Actions

  @impl true
  def mount(_params, _session, socket) do
    socket_new =
      socket
      |> stream(:users, Accounts.list_users_with_order_count())
      |> FlashTimed.clear_after()

    {:ok, socket_new}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `:edit`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, apply_action(socket, act, params, ~p"/users")}
  end

  @impl true
  def handle_info(
        {CloudDbUiWeb.UserLive.FormComponent, {:saved, user}},
        socket
      ) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, delete_user(socket, get_user(socket, id))}
  end

  @spec get_user(%Socket{}, String.t()) :: %User{}
  defp get_user(%{assigns: %{current_user: user}} = _socket, id) do
    cond do
      id == "#{user.id}" -> user
      true -> Accounts.get_user_with_order_count!(id)
    end
  end
end
