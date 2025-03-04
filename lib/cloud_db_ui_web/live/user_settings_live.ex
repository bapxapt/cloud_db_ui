defmodule CloudDbUiWeb.UserSettingsLive do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form
  alias Ecto.Changeset

  import CloudDbUi.StringQueue
  import CloudDbUiWeb.{HTML, Form}

  @type params() :: CloudDbUi.Type.params()

  # The maximal length of the `:taken_emails` queue.
  @taken_emails_limit 10

  # TODO: maybe keep a queue of valid e-mails?

  # TODO: phx-hook="CharacterCounter" with data-value="" for the character counters to ignore phx-debounce

  @impl true
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>
        Manage your account email address and password settings
      </:subtitle>
    </.header>

    <div class="space-y-12 divide-y mx-auto max-w-2xl">
      <.list title_text_class="text-sm font-semibold leading-6 text-zinc-800">
        <:item title="User ID"><%= @current_user.id %></:item>
      </.list>

      <div>
        <.simple_form
          for={@email_form}
          id="email-form"
          bg_class="bg-green-100/90"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input
            field={@email_form[:email]}
            type="text"
            label={label_text_email(@email_form)}
            phx-hook="CharacterCounter"
            phx-debounce="360"
            required
          />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current-password-for-email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />

          <:actions>
            <.button phx-disable-with="Changing...">Change e-mail</.button>
          </:actions>
        </.simple_form>
      </div>

      <div>
        <.simple_form
          for={@password_form}
          id="password-form"
          bg_class="bg-green-100/90"
          action={~p"/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden-user-email"
            value={@current_email}
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label={label_text_password(@password_form)}
            phx-hook="CharacterCounter"
            phx-debounce="360"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label={label_text_password_confirmation(@password_form)}
            phx-hook="CharacterCounter"
            phx-debounce="360"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current-password-for-password"
            value={@current_password}
            required
          />

          <:actions>
            <.button phx-disable-with="Changing...">Change password</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    {:noreply, validate_user_email!(socket, params)}
  end

  def handle_event("update_email", params, socket) do
    {:noreply, update_user_email!(socket, params)}
  end

  def handle_event("validate_password", params, socket) do
    {:noreply, validate_user_password!(socket, params)}
  end

  def handle_event("update_password", params, socket) do
    {:noreply, update_user_password!(socket, params)}
  end

  @spec prepare_socket(%Socket{}, params) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, %{"token" => token}, true = _connected?) do
    case Accounts.update_user_email(socket.assigns.current_user, token) do
      :ok ->
        put_flash(socket, :info, "E-mail changed successfully.")

      :error ->
        put_flash(
          socket,
          :error,
          "E-mail change link is invalid or it has expired."
        )
    end
    |> push_navigate([to: ~p"/settings"])
  end

  # No `"token"` key in params, or `"token"` is in params, but the socket
  # is not `connected?()`.
  defp prepare_socket(%{assigns: %{current_user: user}} = socket, _, _) do
    socket
    |> assign(:current_password, nil)
    |> assign(:email_form_current_password, nil)
    |> assign(:current_email, user.email)
    |> assign(:email_form, to_form(Accounts.change_user_email(user)))
    |> assign(:password_form, to_form(Accounts.change_user_password(user)))
    |> assign(:trigger_submit, false)
    |> assign_queue(:taken_emails)
    |> FlashTimed.clear_after()
  end

  @spec validate_user_email!(%Socket{}, params()) :: %Socket{}
  defp validate_user_email!(
         %{assigns: %{email_form: form} = assigns} = socket,
         %{"current_password" => pass, "user" => user_params} = _params
       ) do
    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> maybe_copy_current_password_errors(
        "#{socket.assigns.email_form_current_password}" == pass,
        form
      )
      |> CloudDbUi.Changeset.maybe_add_unique_constraint_error(
        :email,
        in_queue?(assigns.taken_emails, Map.fetch!(user_params, "email"))
      )
      |> Map.put(:action, :validate)
      |> to_form()

    socket
    |> assign(:email_form, email_form)
    |> assign(:email_form_current_password, pass)
  end

  # If any form error exists, prevent a `Pbkdf2.verify_pass()` call.
  @spec update_user_email!(%Socket{}, params()) :: %Socket{}
  defp update_user_email!(socket, _params)
       when socket.assigns.email_form.errors != [] do
    socket
  end

  defp update_user_email!(socket, %{"user" => user_params} = params) do
    if in_queue?(socket.assigns.taken_emails, user_params["email"]) do
      socket
      |> assign(
        :email_form,
        maybe_add_unique_constraint_error(socket.assigns.email_form, :email)
      )
    else
      socket.assigns.current_user
      |> Accounts.apply_user_email(
        Map.fetch!(params, "current_password"),
        user_params
      )
      |> handle_email_updating_result(socket)
    end
  end

  @spec handle_email_updating_result({:ok, %User{}}, %Socket{}) :: %Socket{}
  defp handle_email_updating_result({:ok, applied_user}, socket) do
    Accounts.deliver_user_update_email_instructions(
      applied_user,
      socket.assigns.current_user.email,
      &url(~p"/settings/confirm_email/#{&1}")
    )

    socket
    |> put_flash(
      :info,
      "A link to confirm your email change has been sent to the new address."
    )
    |> assign(email_form_current_password: nil)
  end

  @spec handle_email_updating_result({:error, %Changeset{}}, %Socket{}) ::
          %Socket{}
  defp handle_email_updating_result({:error, changeset}, socket) do
    socket
    |> assign(:email_form, to_form(Map.put(changeset, :action, :insert)))
    |> maybe_add_taken(:taken_emails, changeset, :email, @taken_emails_limit)
  end

  @spec validate_user_password!(%Socket{}, params()) :: %Socket{}
  defp validate_user_password!(socket, %{"current_password" => pw} = params) do
    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(Map.fetch!(params, "user"))
      |> maybe_copy_current_password_errors(
        "#{socket.assigns.current_password}" == pw,
        socket.assigns.password_form
      )
      |> Map.put(:action, :validate)
      |> to_form()

    assign(socket, [password_form: password_form, current_password: pw])
  end

  # If any form error exists, prevent a `Pbkdf2.verify_pass()` call.
  @spec update_user_password!(%Socket{}, params()) :: %Socket{}
  defp update_user_password!(socket, _params)
       when socket.assigns.password_form.errors != [] do
    socket
  end

  defp update_user_password!(socket, %{"current_password" => pw} = params) do
    socket.assigns.current_user
    |> Accounts.update_user_password(pw, Map.fetch!(params, "user"))
    |> handle_password_updating_result(socket, Map.fetch!(params, "user"))
  end

  @spec handle_password_updating_result({:ok, %User{}}, %Socket{}, params()) ::
          %Socket{}
  defp handle_password_updating_result({:ok, user}, socket, user_params) do
    password_form =
      user
      |> Accounts.change_user_password(user_params)
      |> to_form()

    assign(socket, [trigger_submit: true, password_form: password_form])
  end

  @spec handle_password_updating_result(
          {:error, %Changeset{}},
          %Socket{},
          params()
        ) :: %Socket{}
  defp handle_password_updating_result({:error, changeset}, socket, _params) do
    assign(socket, password_form: to_form(changeset))
  end

  # Copy a `:current_password` error (if exists) from a `form`
  # to a change`set`. This retains an "is invalid" error
  # when the input changes in a field other than the "Current password"
  # field.
  @spec maybe_copy_current_password_errors(%Changeset{}, boolean(), %Form{}) ::
          %Changeset{}
  defp maybe_copy_current_password_errors(set, true = _cp?, %Form{} = form) do
    case get_errors(form, [:current_password]) do
      empty when empty == %{} ->
        set

      %{current_password: errors} ->
        Enum.reduce(errors, set, fn {message, extra_info}, acc ->
          Changeset.add_error(acc, :current_password, message, extra_info)
        end)
    end
  end

  defp maybe_copy_current_password_errors(set, false = _copy?, _form), do: set

  @spec label_text_email(%Form{}) :: String.t()
  defp label_text_email(%Form{} = form) do
    label_text("New e-mail address", form[:email].value, 160)
  end

  @spec label_text_password(%Form{}) :: String.t()
  defp label_text_password(%Form{} = form) do
    label_text("New password", form[:password].value, 72)
  end

  @spec label_text_password_confirmation(%Form{}) :: String.t()
  defp label_text_password_confirmation(%Form{} = form) do
    label_text("Confirm new password", form[:password_confirmation].value, 72)
  end
end
