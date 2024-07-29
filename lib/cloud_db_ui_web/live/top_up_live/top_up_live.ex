defmodule CloudDbUiWeb.TopUpLive do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript

  @type params :: CloudDbUi.Type.params()

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: user}} = socket) do
    socket_new =
      socket
      |> assign(:form, default_form(user))
      |> assign(:page_title, "Top up")

    {:ok, socket_new}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    set = Accounts.top_up_changeset(socket.assigns.current_user, user_params)

    {:noreply, assign(socket, :form, to_form(set, [action: :validate]))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    {:noreply, save_user(socket, user_params)}
  end

  @spec save_user(%Socket{}, params()) :: %Socket{}
  defp save_user(socket, user_params) do
    socket.assigns.current_user
    |> Accounts.top_up_user_balance(user_params)
    |> handle_saving_result(socket, "Topped up successfully.")
  end

  # Success.
  @spec handle_saving_result({:ok, %User{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:ok, saved}, socket, flash_msg) do
    user =
      Map.replace(socket.assigns.current_user, :balance, saved.balance)

    socket
    |> assign(:current_user, user)
    |> assign(:form, default_form(user))
    |> js_set_text("#user-balance", "PLN #{user.balance}")
    |> FlashTimed.put(:info, flash_msg)
  end

  # Failure.
  @spec handle_saving_result(
          {:error, %Ecto.Changeset{}},
          %Socket{},
          String.t()
        ) :: %Socket{}
  defp handle_saving_result({:error, %Ecto.Changeset{} = set}, socket, _msg) do
    assign(socket, :form, to_form(set, [action: :validate]))
  end

  # If `top_up_changeset()` receives an empty map, there will be
  # no error outputted when the page is reloaded even when
  # `user.balance` is at its limit.
  @spec default_form(%User{}) :: %Phoenix.HTML.Form{}
  defp default_form(%User{} = user) do
    user
    |> Accounts.top_up_changeset(%{top_up_amount: user.top_up_amount})
    |> to_form([action: :validate])
  end

  @spec current_balance(%User{}) :: String.t()
  defp current_balance(%User{} = user) do
    case Decimal.compare(user.balance, User.balance_limit()) do
      :eq -> "PLN " <> format(user.balance) <> " (max)"
      _any -> "PLN " <> format(user.balance)
    end
  end
end
