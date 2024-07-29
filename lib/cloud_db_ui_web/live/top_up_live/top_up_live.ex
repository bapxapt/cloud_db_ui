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
    {:ok, assign(socket, :form, to_form(Accounts.top_up_changeset(user)))}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    set = Accounts.top_up_changeset(socket.assigns.current_user, user_params)

    {:noreply, assign(socket, form: to_form(set, [action: :validate]))}
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
  defp handle_saving_result({:ok, object_new}, socket, flash_msg) do
    user_updated =
      Map.replace(socket.assigns.current_user, :balance, object_new.balance)

    socket
    |> assign(:current_user, user_updated)
    |> assign(:form, to_form(Accounts.top_up_changeset(user_updated)))
    |> js_set_text("#user-balance", "PLN #{user_updated.balance}")
    |> FlashTimed.put(:info, flash_msg)
  end

  # Failure.
  @spec handle_saving_result(
          {:error, %Ecto.Changeset{}},
          %Socket{},
          String.t()
        ) :: %Socket{}
  defp handle_saving_result({:error, %Ecto.Changeset{} = set}, socket, _msg) do
    assign(socket, form: to_form(set, [action: :validate]))
  end
end
