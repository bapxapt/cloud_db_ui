defmodule CloudDbUiWeb.UserRegistrationLive do
  use CloudDbUiWeb, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias Ecto.Changeset
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.HTML
  import CloudDbUiWeb.Utilities, only: [trim_downcase: 1]

  @type params() :: CloudDbUi.Type.params()

  # TODO: maybe keep a set of trimmed and down-cased e-mails and add to it each time we hit an "already taken" error?
    # TODO: place a limit of 10 last taken e-mails?

  # TODO: :password_confirmation

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

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(Accounts.change_user_registration(%User{}))
      |> assign(:taken_emails, MapSet.new())

    {:ok, socket}
  end

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
      |> maybe_copy_unique_constrant_error(user_params, socket)

    assign_form(socket, Map.put(changeset, :action, :validate))
  end

  # Any input field has any error. This is needed to prevent
  # `update_user()` or `create_user()`
  # from performing unnecessary unique constraint checks
  # (querying the data base).
  @spec save_user(%Socket{}, params()) :: %Socket{}
  defp save_user(socket, _p) when socket.assigns.form.errors != [], do: socket

  defp save_user(socket, user_params) do
    user_params
    |> Accounts.register_user()
    |> handle_saving_result(socket)
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
  # (not a case change of a letter and not an addition of a space).
  @spec maybe_copy_unique_constrant_error(%Changeset{}, params(), %Socket{}) ::
          %Changeset{}
  defp maybe_copy_unique_constrant_error(set, user_params, socket) do
    error = socket.assigns.form.errors[:email]

    cond do
      !error -> set
      elem(error, 1)[:validation] != :unsafe_unique -> set
      significant_email_change?(user_params, socket) -> set
      true -> Changeset.add_error(set, :email, elem(error, 0), elem(error, 1))
    end
  end

  # Add an e-mail to `socket.assigns.taken_emails`, if the changeset
  # `errors` contain a "has been already taken" error.
  @spec maybe_add_taken_email(%Socket{}, %Changeset{}) :: %Socket{}
  defp maybe_add_taken_email(socket, %Changeset{errors: errors} = set) do
    error = errors[:email]

    cond do
      !error -> socket
      elem(error, 1)[:validation] != :unsafe_unique -> socket
      true -> add_taken_email(socket, trim_downcase(set.changes.email))
    end
  end

  @spec add_taken_email(%Socket{}, String.t()) :: %Socket{}
  defp add_taken_email(%{assigns: %{taken_emails: taken}} = socket, e_mail) do
    assign(socket, :taken_emails, MapSet.put(taken, e_mail))
  end

  # Check whether the `:email` field value differs from its previous
  # state only by a whitespace or only by a letter case change.
  @spec significant_email_change?(params(), %Socket{}) :: boolean()
  defp significant_email_change?(
         %{"email" => email} = _user_params,
         %{assigns: %{form: %{params: prev_params}}} = _socket
       ) do
    trim_downcase(email) != trim_downcase(prev_params["email"])
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
