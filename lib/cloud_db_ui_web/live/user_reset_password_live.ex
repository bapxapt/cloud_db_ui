defmodule CloudDbUiWeb.UserResetPasswordLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts
  alias Phoenix.LiveView.Socket
  alias Ecto.Changeset

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Reset Password</.header>

      <.simple_form
        for={@form}
        id="reset_password_form"
        bg_class="bg-green"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <.error :if={@form.errors != []}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input
          field={@form[:password]}
          type="password"
          label="New password"
          required
        />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          required
        />

        <:actions>
          <.button phx-disable-with="Resetting..." class="w-full">Reset Password</.button>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4">
        <.link href={~p"/users/register"}>Register</.link>
        | <.link href={~p"/users/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    socket_new =
      socket
      |> assign_user_and_token(params)
      |> assign_form(form_source(socket))

    {:ok, socket_new}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    {:noreply, reset_user_password(socket, user_params)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  @spec reset_user_password(%Socket{}, params()) :: %Socket{}
  defp reset_user_password(socket, user_params) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        socket
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: ~p"/users/log_in")

      {:error, changeset} ->
        assign_form(socket, Map.put(changeset, :action, :insert))
    end
  end

  @spec assign_user_and_token(%Socket{}, params()) :: %Socket{}
  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, [user: user, token: token])
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  @spec form_source(%Socket{}) :: %Changeset{} | %{}
  defp form_source(%{assigns: %{user: user}} = _socket) do
    Accounts.change_user_password(user)
  end

  defp form_source(_socket), do: %{}

  @spec assign_form(%Socket{}, %Changeset{} | map()) :: %Socket{}
  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
