defmodule CloudDbUiWeb.UserLoginLive do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUiWeb.FlashTimed

  import CloudDbUiWeb.HTML

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Log in to account
        <:subtitle><%= subtitle() %></:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="log-in-form"
        bg_class="bg-green"
        action={~p"/users/log_in"}
        phx-update="ignore"
      >
        <.input
          field={@form[:email]}
          type="text"
          label={label_text("E-mail address", @form[:email].value, 160)}
          phx-hook="CharacterCounter"
          required
        />
        <.input
          field={@form[:password]}
          type="password"
          label={label_text("Password", @form[:password].value, 72)}
          phx-hook="CharacterCounter"
          required
        />

        <:actions>
          <.input
            field={@form[:remember_me]}
            type="checkbox"
            label="Keep me logged in"
          />
          <.link
            href={~p"/users/reset_password"}
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
  def mount(_params, _session, socket) do
    form =
      to_form(
        %{"email" => Phoenix.Flash.get(socket.assigns.flash, :email)},
        [as: "user"]
      )

    socket_new =
      socket
      |> assign(:form, form)
      |> FlashTimed.clear_after()

    {:ok, socket_new, [temporary_assigns: [form: form]]}
  end

  @spec subtitle() :: [String.t() | {:safe, list()}]
  defp subtitle() do
    [
      "Don't have an account? ",
      link("Sign up", ~p"/users/register", subtitle_link_class()),
      " for an account now."
    ]
  end

  @spec subtitle_link_class() :: String.t()
  defp subtitle_link_class(), do: "font-semibold text-brand hover:underline"
end
