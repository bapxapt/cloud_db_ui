defmodule CloudDbUiWeb.UserForgotPasswordLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts

  import CloudDbUiWeb.Utilities

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
        id="reset_password_form"
        phx-submit="send_email"
      >
        <.input
          field={@form[:email]}
          type="text"
          placeholder="E-mail"
          required
        />

        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send password reset instructions
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
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :form, to_form(%{}, as: "user"))}
  end

  @impl true
  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(trim_downcase(email)) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    socket_new =
      socket
      |> put_flash(:info, info_flash_title())
      |> redirect(to: ~p"/")

    {:noreply, socket_new}
  end

  @spec info_flash_title() :: String.t()
  defp info_flash_title() do
    Kernel.<>(
      "If your e-mail is in our system, you will receive an e-mail ",
      "with instructions to reset your password shortly."
    )
  end
end
