defmodule CloudDbUiWeb.UserRegistrationLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias Ecto.Changeset
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form

  import CloudDbUiWeb.HTML
  import CloudDbUiWeb.Form
  import CloudDbUiWeb.Utilities, except: [assign_form: 2]
  import CloudDbUi.Changeset
  import CloudDbUi.Queue

  @type params() :: CloudDbUi.Type.params()

  # The maximal length of the `:taken_emails` queue.
  @taken_emails_limit 20

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
        id="registration_form"
        bg_class="bg-green"
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
    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(Accounts.change_user_registration(%User{}))
      |> assign_queue(:taken_emails)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, validate_user(socket, user_params)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    {:noreply, save_user(socket, user_params)}
  end

  @spec validate_user(%Socket{}, params()) :: %Socket{}
  defp validate_user(socket, user_params) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> maybe_copy_unique_constraint_error(socket)

    assign_form(socket, Map.put(changeset, :action, :validate))
  end

  # Any input field has any error. This is needed to prevent
  # `update_user()` or `create_user()`
  # from performing unnecessary unique constraint checks
  # (querying the data base).
  @spec save_user(%Socket{}, params()) :: %Socket{}
  defp save_user(socket, _p) when socket.assigns.form.errors != [], do: socket

  defp save_user(socket, %{"email" => e_mail} = user_params) do
    if in_queue?(socket, :taken_emails, e_mail) do
      socket
      |> assign(:check_errors, true)
      |> maybe_add_unique_constraint_error(e_mail)
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
    |> maybe_add_taken_email(changeset)
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

  # Copy an existing "had already been taken" error
  # from `socket.assigns.form.errors` to change`set.errors`, if
  # the value of `:email` received a significant change
  # (not just a case change of a letter and/or not an addition
  # of a trimmable whitespace).
  @spec maybe_copy_unique_constraint_error(%Changeset{}, %Socket{}) ::
          %Changeset{}
  defp maybe_copy_unique_constraint_error(
         %{changes: %{email: e_mail}} = set,
         socket
       ) do
    error = socket.assigns.form.errors[:email]

    cond do
      !error -> set
      elem(error, 1)[:validation] != :unsafe_unique -> set
      significant_change?(e_mail, socket.assigns.form.params["email"]) -> set
      true -> Changeset.add_error(set, :email, elem(error, 0), elem(error, 1))
    end
  end

  # No change of `:email` in `changeset.changes`.
  defp maybe_copy_unique_constraint_error(changeset, _socket), do: changeset

  # Add a new "had already been taken" error, if one is not
  # in `socket.assigns.form.errors` yet, and the `e_mail`
  # is in `:taken_emails`.
  @spec maybe_add_unique_constraint_error(%Socket{}, String.t()) :: %Socket{}
  defp maybe_add_unique_constraint_error(socket, e_mail) do
    error = socket.assigns.form.errors[:email]

    cond do
      error && elem(error, 1)[:validation] == :unsafe_unique -> socket
      !in_queue?(socket, :taken_emails, e_mail) -> socket
      true -> add_form_error(socket, :email, unique_constraint_error(:email))
    end
  end

  # Add an e-mail to `socket.assigns.taken_names`, if
  # change`set.errors` contain a "has been already taken" error.
  # An existing element will get removed if the queue it already
  # at `@taken_emails_limit`.
  @spec maybe_add_taken_email(%Socket{}, %Changeset{}) :: %Socket{}
  defp maybe_add_taken_email(socket, %{changes: %{email: e_mail}} = set) do
    error = set.errors[:email]

    cond do
      !error -> socket
      elem(error, 1)[:validation] != :unsafe_unique -> socket
      true -> add_to_queue(socket, :taken_emails, e_mail, @taken_emails_limit)
    end
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
