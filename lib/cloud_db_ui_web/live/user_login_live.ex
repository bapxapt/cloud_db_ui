defmodule CloudDbUiWeb.UserLoginLive do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  import CloudDbUiWeb.HTML

  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Log in to account
        <:subtitle>{subtitle()}</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="log-in-form"
        bg_class="bg-green-100/90"
        action={~p"/log_in"}
        phx-change="validate"
        phx-submit="log_in"
        phx-trigger-action={@trigger_submit}
      >
        <.input
          field={@form[:email]}
          type="text"
          label={label_text("E-mail address", @form[:email].value, 160)}
          data-value="160"
          phx-hook="CharacterCounter"
          phx-debounce="360"
          required
        />
        <.input
          field={@form[:password]}
          type="password"
          label={label_text("Password", @form[:password].value, 72)}
          data-value="72"
          phx-hook="CharacterCounter"
          phx-debounce="360"
          required
        />

        <:actions>
          <.input
            field={@form[:remember_me]}
            type="checkbox"
            label="Keep me logged in"
          />
          <.link
            href={~p"/reset_password"}
            class="text-sm font-semibold"
          >
            Forgot your password?
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket), do: {:ok, prepare_socket(socket)}

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, validate_user(socket, params)}
  end

  def handle_event("log_in", params, socket) do
    {:noreply, log_in_user(socket, params)}
  end

  @spec prepare_socket(%Socket{}) :: %Socket{}
  defp prepare_socket(%{assigns: %{flash: flash}} = socket) do
    socket
    |> assign(:trigger_submit, false)
    |> assign(
      :form,
      to_form(%{"email" => Phoenix.Flash.get(flash, :email)}, [as: "user"])
    )
    |> FlashTimed.clear_after()
  end

  @spec validate_user(%Socket{}, params()) :: %Socket{}
  defp validate_user(socket, %{"user" => user_params} = _params) do
    changeset =
      user_params
      |> CloudDbUi.Accounts.log_in_changeset()
      |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset, [as: "user"]))
  end

  @spec log_in_user(%Socket{}, params()) :: %Socket{}
  defp log_in_user(socket, params) do
    socket
    |> validate_user(params)
    |> case do
      %{assigns: %{form: %{errors: []}}} = socket ->
        assign(socket, :trigger_submit, true)

      any_socket ->
        any_socket
    end
  end

  @spec subtitle() :: [String.t() | {:safe, list()}]
  defp subtitle() do
    [
      "Don't have an account? ",
      link("Sign up", ~p"/register", subtitle_link_class()),
      " for an account now."
    ]
  end

  @spec subtitle_link_class() :: String.t()
  defp subtitle_link_class(), do: "font-semibold text-brand hover:underline"
end
