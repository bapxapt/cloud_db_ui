defmodule CloudDbUiWeb.UserForgotPasswordLive do
  use CloudDbUiWeb, :live_view

  import CloudDbUiWeb.{Utilities, HTML}

  alias CloudDbUi.Accounts
  alias Phoenix.LiveView.Socket

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Forgot your password?
        <:subtitle>We'll send a password reset link to your inbox</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        bg_class="bg-green-100/90"
        id="forgot-password-form"
        phx-submit="send_email"
        phx-change="validate"
      >
        <.input
          field={@form[:email]}
          type="text"
          placeholder="E-mail"
          label={label_text("E-mail address", @form[:email].value, 160)}
          data-value="160"
          phx-hook="CharacterCounter"
          phx-debounce="360"
          required
        />

        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send password reset instructions
          </.button>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4">
        <.link href={~p"/register"}>Register</.link>
        | <.link href={~p"/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :form, to_form(%{}, as: "user"))}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params} = _params, socket) do
    {:noreply, validate_user_email(socket, user_params)}
  end

  def handle_event("send_email", %{"user" => user_params} = _params, socket) do
    {:noreply, send_email_to_user(socket, user_params)}
  end

  @spec validate_user_email(%Socket{}, params()) :: %Socket{}
  defp validate_user_email(socket, user_params) do
    changeset =
      %Accounts.User{}
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset, [as: "user"]))
  end

  @spec send_email_to_user(%Socket{}, params()) :: %Socket{}
  defp send_email_to_user(socket, %{"email" => e_mail} = user_params) do
    socket
    |> validate_user_email(user_params)
    |> case do
      %{assigns: %{form: %{errors: []}}} = socket ->
        if user = Accounts.get_user_by_email(trim_downcase(e_mail)) do
          Accounts.deliver_user_reset_password_instructions(
            user,
            &url(~p"/reset_password/#{&1}")
          )
        end

        socket
        |> put_flash(:info, info_flash_title())
        |> redirect(to: ~p"/")

      any_socket ->
        any_socket
    end
  end

  @spec info_flash_title() :: String.t()
  defp info_flash_title() do
    Kernel.<>(
      "If your e-mail is in our system, you will receive an e-mail ",
      "with instructions to reset your password shortly."
    )
  end
end
