defmodule CloudDbUiWeb.UserSettingsLive do
  alias CloudDbUiWeb.Form
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form
  alias Ecto.Changeset

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y mx-auto max-w-2xl">
      <.list><:item title="User ID"><%= @current_user.id %></:item></.list>

      <div>
        <.simple_form
          for={@email_form}
          id="email-form"
          bg_class="bg-green"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input
            field={@email_form[:email]}
            type="text"
            label="E-mail"
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
            <.button phx-disable-with="Changing...">Change E-mail</.button>
          </:actions>
        </.simple_form>
      </div>

      <div>
        <.simple_form
          for={@password_form}
          id="password-form"
          bg_class="bg-green"
          action={~p"/users/log_in?_action=password_updated"}
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
            label="New password"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
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
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token} = _params, _session, socket) do
    socket_new =
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
      |> push_navigate([to: ~p"/users/settings"])

    {:ok, socket_new}
  end

  def mount(_params, _session, %{assigns: %{current_user: user}} = socket) do
    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(Accounts.change_user_email(user)))
      |> assign(:password_form, to_form(Accounts.change_user_password(user)))
      |> assign(:trigger_submit, false)
      |> FlashTimed.clear_after()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    {:noreply, validate_user_email(socket, params)}
  end

  def handle_event("update_email", params, socket) do
    {:noreply, update_user_email(socket, params)}
  end

  def handle_event("validate_password", params, socket) do
    {:noreply, validate_user_password(socket, params)}
  end

  def handle_event("update_password", params, socket) do
    {:noreply, update_user_password(socket, params)}
  end

  @spec validate_user_email(%Socket{}, params()) :: %Socket{}
  defp validate_user_email(socket, %{"current_password" => pass} = params) do
    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(Map.fetch!(params, "user"))
      |> maybe_copy_current_password_error(
        "#{socket.assigns.email_form_current_password}" == pass,
        socket.assigns.email_form
      )
      |> Map.put(:action, :validate)
      |> to_form()

    socket
    |> assign(:email_form, email_form)
    |> assign(:email_form_current_password, pass)
  end

  # If any form error exists, prevent a `Pbkdf2.verify_pass()` call.
  @spec update_user_email(%Socket{}, params()) :: %Socket{}
  defp update_user_email(socket, _params)
       when socket.assigns.email_form.errors != [] do
    socket
  end

  defp update_user_email(socket, %{"current_password" => pass} = params) do
    socket.assigns.current_user
    |> Accounts.apply_user_email(pass, Map.fetch!(params, "user"))
    |> handle_email_updating_result(socket)
  end

  @spec handle_email_updating_result({:ok, %User{}}, %Socket{}) :: %Socket{}
  defp handle_email_updating_result({:ok, applied_user}, socket) do
    Accounts.deliver_user_update_email_instructions(
      applied_user,
      socket.assigns.current_user.email,
      &url(~p"/users/settings/confirm_email/#{&1}")
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
    assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))
  end

  @spec validate_user_password(%Socket{}, params()) :: %Socket{}
  defp validate_user_password(socket, %{"current_password" => pw} = params) do
    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(Map.fetch!(params, "user"))
      |> maybe_copy_current_password_error(
        "#{socket.assigns.current_password}" == pw,
        socket.assigns.password_form
      )
      |> Map.put(:action, :validate)
      |> to_form()

    assign(socket, [password_form: password_form, current_password: pw])
  end

  # If any form error exists, prevent a `Pbkdf2.verify_pass()` call.
  @spec update_user_password(%Socket{}, params()) :: %Socket{}
  defp update_user_password(socket, _params)
       when socket.assigns.password_form.errors != [] do
    socket
  end

  defp update_user_password(socket, %{"current_password" => pw} = params) do
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
  # to a change`set`. This prevents clearing of an "is invalid" error
  # when the input changes in a field other than the "Current password"
  # field.
  @spec maybe_copy_current_password_error(%Changeset{}, boolean(), %Form{}) ::
          %Changeset{}
  defp maybe_copy_current_password_error(set, true = _copy?, form) do
    case form.errors[:current_password] do
      nil -> set
      {msg, keys} -> Changeset.add_error(set, :current_password, msg, keys)
    end
  end

  defp maybe_copy_current_password_error(set, false = _copy?, _form), do: set
end
