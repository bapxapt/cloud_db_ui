defmodule CloudDbUiWeb.UserResetPasswordLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form
  alias Ecto.Changeset

  import CloudDbUiWeb.HTML

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Reset password</.header>

      <.simple_form
        for={@form}
        id="reset-form"
        bg_class="bg-green-100/90"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <.error :if={display_error_message?(@form, @changed_fields)}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input
          field={@form[:password]}
          type="password"
          label={label_text("New password", @form[:password].value, 72)}
          required
        />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          phx-debounce="300"
          label={label_text_password_confirmation(@form)}
          required
        />

        <:actions>
          <.button phx-disable-with="Resetting..." class="w-full">
            Reset password
          </.button>
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
    {:ok, prepare_socket(socket, params)}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    {:noreply, reset_user_password(socket, user_params)}
  end

  def handle_event("validate", params, socket) do
    {:noreply, validate_user!(socket, params)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
    |> assign_form()
    |> assign(:changed_fields, MapSet.new())
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, params, true = _connected?) do
    assign_user_and_token(socket, params)
  end

  defp prepare_socket(socket, _params, false = _connected?), do: socket

  @spec assign_user_and_token(%Socket{}, params()) :: %Socket{}
  defp assign_user_and_token(socket, %{"token" => token} = _params) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, [user: user, token: token])
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  @spec reset_user_password(%Socket{}, params()) :: %Socket{}
  defp reset_user_password(%{assigns: %{user: user}} = socket, user_params) do
    case Accounts.reset_user_password(user, user_params) do
      {:ok, _user} ->
        socket
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: ~p"/users/log_in")

      {:error, changeset} ->
        assign_form(socket, Map.put(changeset, :action, :insert))
    end
  end

  @spec validate_user!(%Socket{}, params()) :: %Socket{}
  defp validate_user!(%{assigns: %{user: user}} = socket, params) do
    changeset =
      user
      |> Accounts.change_user_password(Map.fetch!(params, "user"))
      |> Map.put(:action, :validate)

    socket
    |> maybe_add_to_changed_fields(params)
    |> assign_form(changeset)
  end

  @spec maybe_add_to_changed_fields(%Socket{}, params()) :: %Socket{}
  defp maybe_add_to_changed_fields(socket, %{"_target" => ["user", field]}) do
    update(
      socket,
      :changed_fields,
      &MapSet.put(&1, String.to_existing_atom(field))
    )
  end

  # No `"_target"` key, or its value has a wrong shape.
  defp maybe_add_to_changed_fields(socket, _params), do: socket

  @spec assign_form(%Socket{}) :: %Socket{}
  defp assign_form(%{assigns: %{user: user}} = socket) do
    assign_form(socket, Accounts.change_user_password(user))
  end

  # No `:user` key in `socket.assigns`.
  defp assign_form(socket), do: assign_form(socket, %{})

  @spec assign_form(%Socket{}, %Changeset{} | map()) :: %Socket{}
  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, [as: "user"]))
  end

  # Whether to display the "Oops, something went wrong!" message
  # above the input fields.
  @spec display_error_message?(%Form{}, MapSet.t(atom())) :: boolean()
  defp display_error_message?(%Form{errors: errors} = _form, changed) do
    Kernel.and(
      :password_confirmation in changed or errors[:password] != nil,
      :password in changed or errors[:password_confirmation] != nil
    )
  end

  @spec label_text_password_confirmation(%Form{}) :: String.t()
  defp label_text_password_confirmation(%Form{} = form) do
    label_text("Confirm new password", form[:password_confirmation].value, 72)
  end
end
