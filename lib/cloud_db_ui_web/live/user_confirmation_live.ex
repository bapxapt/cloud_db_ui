defmodule CloudDbUiWeb.UserConfirmationLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts

  # TODO: test

  # TODO: use FlashTimed?

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form
        for={@form}
        bg_class="bg-green"
        id="confirmation_form"
        phx-submit="confirm"
      >
        <input
          type="hidden"
          name={@form[:token].name}
          value={@form[:token].value}
        />

        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">
            Confirm my account
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

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")

    {:ok, assign(socket, form: form), [temporary_assigns: [form: nil]]}
  end

  # TODO: split into smaller functions

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{confirmed_at: at}} when not is_nil(at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            socket_new =
              socket
              |> put_flash(
                :error,
                "User confirmation link is invalid or it has expired."
              )
              |> redirect(to: ~p"/")

            {:noreply, socket_new}
        end
    end
  end
end
