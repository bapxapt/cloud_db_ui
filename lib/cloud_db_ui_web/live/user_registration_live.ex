defmodule CloudDbUiWeb.UserRegistrationLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias Ecto.Changeset
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form

  import CloudDbUi.StringQueue
  import CloudDbUiWeb.HTML
  import CloudDbUiWeb.Form

  @type params() :: CloudDbUi.Type.params()

  # The maximal length of the `:taken_emails` queue.
  @taken_emails_limit 10

  # TODO: maybe keep a queue of valid e-mails?

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle><%= subtitle() %></:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration-form"
        bg_class="bg-green-100/90"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input
          field={@form[:email]}
          type="text"
          label={label_text("E-mail address", @form[:email].value, 160)}
          required
        />
        <.input
          field={@form[:password]}
          type="password"
          label={label_text("Password", @form[:password].value, 72)}
          required
        />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label={label_text_password_confirmation(@form)}
        />

        <:actions>
          <.button
            phx-disable-with="Creating account..."
            class="w-full"
          >
            Create an account
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, prepare_socket(socket)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, validate_user(socket, user_params)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    {:noreply, save_user(socket, user_params)}
  end

  @spec prepare_socket(%Socket{}) :: %Socket{}
  defp prepare_socket(socket) do
    socket
    |> assign([trigger_submit: false, check_errors: false])
    |> assign_form(Accounts.change_user_registration(%User{}))
    |> assign_queue(:taken_emails)
  end

  @spec validate_user(%Socket{}, params()) :: %Socket{}
  defp validate_user(socket, %{"email" => e_mail} = user_params) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> CloudDbUi.Changeset.maybe_add_unique_constraint_error(
        :email,
        in_queue?(socket.assigns.taken_emails, e_mail)
      )

    assign_form(socket, Map.put(changeset, :action, :validate))
  end

  # Any input field has any error. This is needed to prevent
  # `update_user()` or `create_user()`
  # from performing unnecessary unique constraint checks
  # (querying the data base).
  @spec save_user(%Socket{}, params()) :: %Socket{}
  defp save_user(socket, _p) when socket.assigns.form.errors != [], do: socket

  defp save_user(socket, %{"email" => e_mail} = user_params) do
    if in_queue?(socket.assigns.taken_emails, e_mail) do
      socket
      |> assign(:check_errors, true)
      |> assign(
        :form,
        maybe_add_unique_constraint_error(socket.assigns.form, :email)
      )
    else
      user_params
      |> Accounts.register_user()
      |> handle_saving_result(socket)
    end
  end

  # Success.
  @spec handle_saving_result({:ok, %User{}}, %Socket{}) :: %Socket{}
  defp handle_saving_result({:ok, user}, socket) do
    {:ok, _} =
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )

    socket
    |> assign(:trigger_submit, true)
    |> assign_form(Accounts.change_user_registration(user))
  end

  # Failure.
  @spec handle_saving_result({:error, %Changeset{}}, %Socket{}) :: %Socket{}
  defp handle_saving_result({:error, %Changeset{} = changeset}, socket) do
    socket
    |> assign(:check_errors, true)
    |> assign_form(changeset)
    |> maybe_add_taken(:taken_emails, changeset, :email, @taken_emails_limit)
  end

  @spec assign_form(%Socket{}, %Changeset{}) :: %Socket{}
  defp assign_form(socket, %Changeset{valid?: true} = changeset) do
    socket
    |> assign(:form, to_form(changeset, as: "user"))
    |> assign(:check_errors, false)
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end

  @spec label_text_password_confirmation(%Form{}) :: String.t()
  defp label_text_password_confirmation(%Form{} = form) do
    label_text("Password confirmation", form[:password_confirmation].value, 72)
  end

  @spec subtitle() :: [String.t() | {:safe, list()}]
  defp subtitle() do
    [
      "Already registered? ",
      link("Log in", ~p"/users/log_in", subtitle_link_class()),
      " to your account now."
    ]
  end

  @spec subtitle_link_class() :: String.t()
  defp subtitle_link_class(), do: "font-semibold text-brand hover:underline"
end
