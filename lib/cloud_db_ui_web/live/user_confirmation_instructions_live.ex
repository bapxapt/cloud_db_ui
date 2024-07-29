defmodule CloudDbUiWeb.UserConfirmationInstructionsLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts

  # TODO: make sure that :email is case-insensitive

  # TODO: allow trimmable spaces in :email

  # TODO: use FlashTimed?

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        No confirmation instructions received?
        <:subtitle>We'll send a new confirmation link to your inbox</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        bg_class="bg-green"
        id="resend_confirmation_form"
        phx-submit="send"
      >
        <.input
          field={@form[:email]}
          type="email"
          placeholder="E-mail"
          required
        />

        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation instructions
          </.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/users/register"}>Register</.link>
        | <.link href={~p"/users/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    socket_new =
      socket
      |> put_flash(:info, flash_info_title())
      |> redirect(to: ~p"/")

    {:noreply, socket_new}
  end

  @spec flash_info_title() :: String.t()
  defp flash_info_title() do
    """
    If your email is in our system and it has not been confirmed yet,
    you will receive an email with instructions shortly.
    """
  end
end
