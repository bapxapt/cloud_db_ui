defmodule CloudDbUiWeb.UserConfirmationInstructionsLive do
  use CloudDbUiWeb, :live_view

  import CloudDbUiWeb.Utilities

  alias CloudDbUi.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        No confirmation instructions received?
        <:subtitle>We'll send a new confirmation link to your inbox</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        bg_class="bg-green-100/90"
        id="resend-confirmation-form"
        phx-submit="send"
      >
        <.input
          field={@form[:email]}
          type="text"
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

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :form, to_form(%{}, as: "user"))}
  end

  @impl true
  def handle_event("send", %{"user" => %{"email" => untrimmed}}, socket) do
    if user = Accounts.get_user_by_email(trim_downcase(untrimmed)) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
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
      "If your e-mail is in our system and it has not been confirmed yet, ",
      "you will receive an e-mail with instructions shortly."
    )
  end
end
