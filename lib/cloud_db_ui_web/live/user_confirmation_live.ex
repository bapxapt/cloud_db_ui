defmodule CloudDbUiWeb.UserConfirmationLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts
  alias Phoenix.LiveView.Socket

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form
        for={@form}
        bg_class="bg-green-100/90"
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
        <.link href={~p"/register"}>Register</.link>
        | <.link href={~p"/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params), [temporary_assigns: [form: nil]]}
  end

  @impl true
  def handle_event("confirm", %{"user" => %{"token" => token}}, socket) do
    {:noreply, confirm_user(socket, token)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, %{"token" => token} = _params) do
    assign(socket, :form, to_form(%{"token" => token}, [as: "user"]))
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  @spec confirm_user(%Socket{}, String.t()) :: %Socket{}
  defp confirm_user(socket, token) do
    case Accounts.confirm_user(token) do
      {:ok, _} -> put_flash(socket, :info, "User confirmed successfully.")
      # If there is a current user and the account was already confirmed,
      # then odds are that the confirmation link was already visited, either
      # by some automation or by the user themselves, so we put
      # a warning message.
      :error -> put_flash(socket, :error, error_flash_title(socket))
    end
    |> redirect([to: ~p"/"])
  end

  @spec error_flash_title(%Socket{}) :: String.t()
  defp error_flash_title(%{assigns: %{current_user: %{confirmed_at: at}}})
       when at != nil do
    "User has already been confirmed."
  end

  # No `:current_user` in `socket.assigns`, or `:current_user` is `nil`,
  # or `socket.assigns.current_user.confirmed_at` is `nil`.
  defp error_flash_title(_socket) do
    "User confirmation link is invalid or it has expired."
  end
end
