defmodule CloudDbUiWeb.UserLive.FormComponent do
  use CloudDbUiWeb, :live_component

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias Phoenix.LiveView.Socket
  alias Ecto.Changeset

  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.HTML

  @type params :: CloudDbUi.Type.params()

  # TODO: maybe keep a set of trimmed and down-cased e-mails and add to it each time we hit an "already taken" error?

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>
          Use this form to manage user records in your database.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:email]}
          type="text"
          label={label_text("E-mail address", @form[:email].value, 160)}
          phx-debounce="blur"
        />
        <.input
          :if={display_confirmation_email?(@user, @form)}
          field={@form[:email_confirmation]}
          type="text"
          label={label_text_email_confirmation(@form)}
        />
        <hr />
        <.button
          :if={@action == :edit and !@change_password}
          type="button"
          phx-target={@myself}
          phx-click="change_password"
        >
          Change password
        </.button>
        <.input
          :if={@action == :new or @change_password}
          field={@form[:password]}
          type="password"
          label={label_text_password(@form, @action)}
        />
        <.input
          :if={display_confirmation_password?(@form, :password)}
          field={@form[:password_confirmation]}
          type="password"
          label={label_text_password_confirmation(@form)}
        />
        <hr />
        <.input
          field={@form[:confirmed_at]}
          type="datetime-local"
          label="E-mail confirmation date and time (UTC)"
        />
        <.input
          field={@form[:balance]}
          type="text"
          inputmode="decimal"
          label="Balance, PLN"
          value={maybe_format(@form, :balance)}
        />
        <.input
          field={@form[:active]}
          type="checkbox"
          label="Active"
        />
        <.input
          field={@form[:admin]}
          type="checkbox"
          label="Administrator"
          disabled="true"
        />

        <:actions>
          <.button phx-disable-with="Saving...">Save user</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(socket), do: {:ok, assign(socket, :change_password, false)}

  @impl true
  def update(%{user: user} = assigns, socket) do
    socket_new =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(Accounts.change_user(user)) end)

    {:ok, socket_new}
  end

  @impl true
  def handle_event("change_password", _params, socket) do
    {:noreply, assign(socket, :change_password, true)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, validate_user(socket, user_params)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    {:noreply, save_user(socket, socket.assigns.action, user_params)}
  end

  @spec validate_user(%Socket{}, params()) :: %Socket{}
  defp validate_user(%{assigns: %{user: user}} = socket, user_params) do
    changeset =
      Accounts.change_user(
        user,
        user_params,
        significant_email_change?(user_params, socket),
        socket.assigns.form.errors
      )

    assign(socket, form: to_form(changeset, [action: :validate]))
  end

  # Any input field has any error. This is needed to prevent
  # `update_user()` or `create_user()`
  # from performing unnecessary unique constraint checks
  # (querying the data base).
  @spec save_user(%Socket{}, atom(), params()) :: %Socket{}
  defp save_user(socket, _action, _user_params)
       when socket.assigns.form.errors != [] do
    socket
  end

  defp save_user(socket, :edit, user_params) do
    socket.assigns.user
    |> Accounts.update_user(user_params)
    |> handle_saving_result(
      socket,
      "User ID #{socket.assigns.user.id} updated successfully."
    )
  end

  defp save_user(socket, :new, user_params) do
    user_params
    |> Accounts.create_user(:via_form)
    |> handle_saving_result(socket, "User created successfully.")
  end

  # Success.
  @spec handle_saving_result({:ok, %User{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:ok, user}, socket, flash_msg) do
    user_new =
      user
      |> Map.replace!(:orders, socket.assigns.user.orders)
      |> Map.replace!(:paid_orders, socket.assigns.user.paid_orders)

    notify_parent({:saved, user_new})
    notify_parent({:put_flash, :info, flash_msg})
    push_patch(socket, [to: socket.assigns.patch])
  end

  # Failure.
  @spec handle_saving_result({:error, %Changeset{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:error, %Changeset{} = set}, socket, _msg) do
    assign(socket, form: to_form(set, [action: :validate]))
  end

  # Check whether the `:email` field value differs from its previous
  # state or from `user.email` only by a whitespace or only by a letter
  # case change.
  @spec significant_email_change?(params(), %Socket{}) :: boolean()
  defp significant_email_change?(
         %{"email" => email} = _user_params,
         %{assigns: %{form: %{params: prev_params}, user: user}} = _socket
       ) do
    trimmed_downcased = trim_downcase(email)

    cond do
      trimmed_downcased == trim_downcase(prev_params["email"]) -> false
      trimmed_downcased == user.email -> false
      true -> true
    end
  end

  @spec display_confirmation_email?(%User{}, %Phoenix.HTML.Form{}) :: boolean()
  defp display_confirmation_email?(%User{} = user, form) do
    cond do
      !Map.has_key?(form.source.changes, :email) -> false
      trim(form.source.changes.email) == user.email -> false
      String.downcase(form.source.changes.email) == user.email -> false
      true -> true
    end
  end

  @spec display_confirmation_password?(%Phoenix.HTML.Form{}, atom()) ::
          boolean()
  defp display_confirmation_password?(
         %{source: %Changeset{changes: changes}, errors: errors} = _form,
         field
       ) do
    Map.has_key?(changes, field) and !Keyword.has_key?(errors, field)
  end

  @spec label_text_email_confirmation(%Phoenix.HTML.Form{}) :: String.t()
  defp label_text_email_confirmation(%Phoenix.HTML.Form{} = form) do
    label_text("E-mail confirmation", form[:email_confirmation].value, 160)
  end

  @spec label_text_password(%Phoenix.HTML.Form{}, atom()) :: String.t()
  defp label_text_password(%Phoenix.HTML.Form{} = form, action) do
    action
    |> label_password()
    |> label_text(form[:password].value, 72)
  end

  @spec label_text_password_confirmation(%Phoenix.HTML.Form{}) :: String.t()
  defp label_text_password_confirmation(%Phoenix.HTML.Form{} = form) do
    label_text("Password confirmation", form[:password_confirmation].value, 72)
  end

  @spec label_password(atom()) :: String.t()
  defp label_password(:new), do: "New password"

  defp label_password(:edit), do: "New password (optional)"

  @spec notify_parent(any()) :: any()
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
