defmodule CloudDbUiWeb.UserLoginLive do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.HTML

  # TODO: when log in is pressed, validate that the e-mail address passes User.valid_email?()
    # TODO: and do not query the DB if it does not
      # TODO: should likely use phx-trigger-action={@trigger_submit}

  # TODO: when log in is pressed, validate that the password has 8-72 characters
    # TODO: and do not query the DB if it does not
      # TODO: should likely use phx-trigger-action={@trigger_submit}

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
        bg_class="bg-green-100/90"
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
    socket_new = prepare_socket(socket)

    {:ok, socket_new, [temporary_assigns: [form: socket_new.assigns.form]]}
  end

  # TODO: use or remove

  #@impl true
  #def handle_event("log_in", params, socket) do

  #  # TODO: remove
  #  IO.puts("\n\n    IN handle_event(log_in)")
  #  IO.inspect(params)
  #  IO.puts("\n\n")

  #  # TODO: HTTPoison POST request?

  #  {:noreply, assign(socket, :trigger_submit, true)}
  #end

  @spec prepare_socket(%Socket{}) :: %Socket{}
  defp prepare_socket(%{assigns: %{flash: flash}} = socket) do
    socket
    # TODO: |> assign(:trigger_submit, false)
    |> assign(
      :form,
      to_form(%{"email" => Phoenix.Flash.get(flash, :email)}, [as: "user"])
    )
    |> FlashTimed.clear_after()
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
