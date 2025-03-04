defmodule CloudDbUiWeb.UserLive.FormComponent do
  use CloudDbUiWeb, :live_component

  import CloudDbUiWeb.{Utilities, HTML}
  import CloudDbUi.{StringQueue, Changeset}

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form
  alias Ecto.Changeset

  @type params :: CloudDbUi.Type.params()

  # The maximal length of the `:taken_emails` queue.
  @taken_emails_limit 10

  # TODO: maybe keep a queue of valid e-mails?

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
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
          data-value="160"
          phx-hook="CharacterCounter"
        />
        <.input
          :if={display_email_confirmation?(@user, @form, @action)}
          field={@form[:email_confirmation]}
          type="text"
          phx-target={@myself}
          phx-blur="validate"
          phx-value-user={encoded_form_field_values(@form)}
          label={label_text_email_confirmation(@form)}
        />
        <hr />

        <.button
          :if={!@display_password_field?}
          type="button"
          phx-target={@myself}
          phx-click="display_password_field"
        >
          Change password
        </.button>
        <.input
          :if={@display_password_field?}
          field={@form[:password]}
          type="password"
          phx-debounce="360"
          label={label_text_password(@form, @action)}
        />
        <.input
          :if={display_password_confirmation_field?(@form, @action)}
          field={@form[:password_confirmation]}
          type="password"
          phx-target={@myself}
          phx-blur="validate"
          phx-value-user={encoded_form_field_values(@form)}
          label={label_text_password_confirmation(@form)}
        />
        <hr />

        <.input
          :if={@action == :new}
          field={@form[:confirmed]}
          type="checkbox"
          label="E-mail address confirmed"
        />
        <.input
          :if={@action == :edit}
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
  def mount(socket), do: {:ok, assign_queue(socket, :taken_emails)}

  @impl true
  def update(%{user: user} = assigns, socket) do
    socket_new =
      socket
      |> assign(assigns)
      |> assign_display_password_field()
      |> assign_new(:form, fn -> to_form(Accounts.change_user(user)) end)

    {:ok, socket_new}
  end

  @impl true
  def handle_event("display_password_field", _params, socket) do
    {:noreply, assign(socket, :display_password_field?, true)}
  end

  def handle_event("validate", %{"user" => _user_params} = params, socket) do
    {:noreply, validate_user(socket, params)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    {:noreply, save_user(socket, socket.assigns.action, user_params)}
  end

  # The `:email_confirmation`/`:password_confirmation` input field
  # got unfocused (blurred).
  @spec validate_user(%Socket{}, params() | String.t()) :: %Socket{}
  defp validate_user(socket, %{"user" => user_params} = params)
       when is_binary(user_params) do
    validate_user(socket, Map.update!(params, "user", &Jason.decode!(&1)))
  end

  defp validate_user(
         %{assigns: %{user: user}} = socket,
         %{"user" => user_params} = params
       ) do
    changeset =
      Accounts.change_user(
        user,
        user_params,
        validate_unique_constraint?(user_params["email"], socket),
        params["_target"]
      )
      |> maybe_add_unique_constraint_error(
        :email,
        in_queue?(socket.assigns.taken_emails, user_params["email"])
      )

    socket
    |> assign(:form, to_form(changeset, [action: :validate]))
    |> maybe_add_taken(:taken_emails, changeset, :email, @taken_emails_limit)
  end

  # Any input field has any error. This is needed to prevent
  # `update_user()` or `create_user()` from performing unnecessary
  # unique constraint checks (and querying the data base).
  @spec save_user(%Socket{}, atom(), params()) :: %Socket{}
  defp save_user(socket, _action, _p) when socket.assigns.form.errors != [] do
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
    |> Accounts.create_user_in_form()
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

    case socket.assigns.action do
      :new ->
        notify_parent({:saved, user_new, true})

      :edit ->
        refilter? =
          CloudDbUiWeb.Flop.refilter?(
            socket.assigns.user,
            user_new,
            [:email, :confirmed_at, :balance, :active]
          )

        notify_parent({:saved, user_new, refilter?})
    end

    notify_parent({:put_flash, :info, flash_msg})
    push_patch(socket, [to: socket.assigns.patch])
  end

  # Failure.
  @spec handle_saving_result({:error, %Changeset{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:error, %Changeset{} = set}, socket, _msg) do
    assign(socket, :form, to_form(set, [action: :validate]))
  end

  # Validation of a unique constraint is not needed if:
  #
  #   - the only change of `:email` that happened is an addition
  #     of a trimmable whitespace or a case change of a letter;
  #   - the `e_mail` is in `socket.assigns.taken_emails`;
  #   - the `e_mail` is the same as `user.email`.
  @spec validate_unique_constraint?(String.t(), %Socket{}) :: boolean()
  defp validate_unique_constraint?(mail, %{assigns: %{user: usr} = assigns}) do
    cond do
      !significant_change?(mail, assigns.form.params["email"]) -> false
      in_queue?(assigns.taken_emails, mail) -> false
      trim_downcase(mail) == String.downcase("#{usr.email}") -> false
      true -> true
    end
  end

  # Return a map of params artificially created from a `form`.
  @spec encoded_form_field_values(%Form{}) :: String.t()
  defp encoded_form_field_values(%Form{} = form) do
    [
      :email,
      :email_confirmation,
      :password,
      :password_confirmation,
      :confirmed,
      :confirmed_at,
      :balance,
      :active,
      :admin
    ]
    |> Map.new(fn field ->
      case form[field].value do
        %Decimal{} = value -> {"#{field}", Decimal.to_string(value, :normal)}
        any -> {"#{field}", "#{any}"}
      end
    end)
    |> Jason.encode!()
  end

  # Do not display the `:email_confirmation` input field
  # while editing (`action` is not `:new`) a user if:
  #
  #   - there are no changes for the `:email` field;
  #   - the current value of the `:email` field differs from `user.email`
  #     only by trimmable whitespaces and/or by letter case changes.
  @spec display_email_confirmation?(%User{}, %Form{}, atom()) :: boolean()
  defp display_email_confirmation?(%User{} = user, form, action) do
    cond do
      action == :new -> true
      !Map.has_key?(form.source.changes, :email) -> false
      trim_downcase(form.source.changes.email) == user.email -> false
      true -> true
    end
  end

  # Do not display the `:email_confirmation` input field
  # while editing (`action` is not `:new`) a user if the `:password` field
  # is blank.
  @spec display_password_confirmation_field?(%Form{}, atom()) ::
          boolean()
  defp display_password_confirmation_field?(%Form{} = form, action) do
    action == :new or form[:password].value not in [nil, ""]
  end

  @spec assign_display_password_field(%Socket{}) :: %Socket{}
  defp assign_display_password_field(%{assigns: %{action: :new}} = socket) do
    assign(socket, :display_password_field?, true)
  end

  defp assign_display_password_field(%{assigns: %{action: :edit}} = socket) do
    assign(socket, :display_password_field?, false)
  end

  @spec label_text_email_confirmation(%Form{}) :: String.t()
  defp label_text_email_confirmation(%Form{} = form) do
    label_text(
      "E-mail address confirmation",
      form[:email_confirmation].value,
      160
    )
  end

  @spec label_text_password(%Form{}, atom()) :: String.t()
  defp label_text_password(%Form{} = form, action) do
    action
    |> label_password()
    |> label_text(form[:password].value, 72)
  end

  @spec label_text_password_confirmation(%Form{}) :: String.t()
  defp label_text_password_confirmation(%Form{} = form) do
    label_text("Password confirmation", form[:password_confirmation].value, 72)
  end

  @spec label_password(atom()) :: String.t()
  defp label_password(:new), do: "Password"

  defp label_password(:edit), do: "New password (optional)"
end
