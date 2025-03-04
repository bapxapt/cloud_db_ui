defmodule CloudDbUi.Accounts do
  @moduledoc """
  The Accounts context.
  """
  import CloudDbUiWeb.Utilities
  import CloudDbUi.Changeset, [only: [put_changes_from_attrs: 3]]
  import Ecto.Query, warn: false

  alias CloudDbUi.Repo
  alias CloudDbUi.Accounts.{User, UserToken, UserNotifier}
  alias CloudDbUi.Accounts.User.Query
  alias Ecto.Changeset

  @type db_id() :: CloudDbUi.Type.db_id()
  @type attrs() :: CloudDbUi.Type.attrs()

  ## Database getters

  @doc """
  List all users. Replaces `:orders` with order count.
  Fills the `:paid_orders` virtual field.
  """
  @spec list_users_with_order_count(%Flop{}) ::
          {:ok, {[%User{}], %Flop.Meta{}}} | {:error, %Flop.Meta{}}
  def list_users_with_order_count(%Flop{} = flop \\ %Flop{}) do
    Query.with_order_count()
    |> Flop.validate_and_run(flop, [for: User])
  end

  @doc """
  Get a single user. Preloads `:orders`. Each order has preloaded
  `:suborders`, and each sub-order has a preloaded `:product`.
  Fills the `:paid_orders` virtual field.
  """
  @spec get_user_with_order_suborder_products!(db_id()) :: %User{}
  def get_user_with_order_suborder_products!(id) do
    Query.with_preloaded_order_suborder_products()
    |> Repo.get!(id)
    |> User.fill_paid_orders()
  end

  @doc """
  Get a single user. Replaces `:orders` with order count.
  Fills the `:paid_orders` virtual field.
  """
  @spec get_user_with_order_count!(db_id()) :: %User{}
  def get_user_with_order_count!(id) do
    Query.with_order_count()
    |> Repo.get!(id)
  end

  @doc """
  Get a user by e-mail. No preloads.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  @spec get_user_by_email(db_id()) :: %User{} | nil
  def get_user_by_email(e_mail) when is_binary(e_mail) do
    Repo.get_by(User, [email: e_mail])
  end

  @doc """
  Get a user by e-mail and password. No preloads.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_pass")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_pass")
      nil

  """
  @spec get_user_by_email_and_password(String.t(), String.t()) :: %User{} | nil
  def get_user_by_email_and_password(e_mail, password) do
    user = Repo.get_by(User, [email: e_mail])

    if User.valid_password?(user, password), do: user
  end

  @doc """
  Get a user by ID or by e-mail. No preloads.
  """
  @spec get_user_by_id_or_email(db_id()) :: %User{} | nil
  def get_user_by_id_or_email(id_or_email) do
    case valid_id?(id_or_email) do
      true -> Repo.get(User, id_or_email)
      false -> get_user_by_email(id_or_email)
    end
  end

  ## User registration

  @doc """
  Register a non-administrator user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec register_user(attrs(), keyword()) ::
          {:ok, %User{}} | {:error, %Changeset{}}
  def register_user(attrs \\ %{}, opts \\ []) do
    %User{}
    |> User.registration_saving_changeset(attrs, opts)
    |> Repo.insert()
  end

  @doc """
  Create a user (that can possibly be an administrator), for example,
  while seeding the data base.
  """
  @spec create_user(attrs()) :: {:ok, %User{}} | {:error, %Changeset{}}
  def create_user(attrs \\ %{}) do
    attrs
    |> User.creation_changeset()
    |> Repo.insert()
  end

  @doc """
  Create a user via `CloudDbUiWeb.UserLive.FormComponent` as an admin.
  """
  @spec create_user_in_form(attrs()) :: {:ok, %User{}} | {:error, %Changeset{}}
  def create_user_in_form(attrs) do
    %User{}
    |> User.saving_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Return an `%Ecto.Changeset{}` for tracking user changes
  when editing a user as an admin.
  """
  @spec change_user(%User{}, attrs(), boolean(), [String.t()] | nil) ::
          %Changeset{}
  def change_user(
        %User{} = user,
        attrs \\ %{},
        validate_unique? \\ true,
        target \\ nil
      ) do
    User.validation_changeset(user, attrs, validate_unique?, target)
  end

  @doc """
  Return an `%Ecto.Changeset{}` for tracking user changes
  during the registration process.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  @spec change_user_registration(%User{}, attrs()) :: %Changeset{}
  def change_user_registration(%User{} = user, %{} = attrs \\ %{}) do
    User.registration_validation_changeset(
      user,
      attrs,
      [hash_password: false, validate_unique_email: false]
    )
  end

  ## Logging in

  @doc """
  Return an `%Ecto.Changeset{}` for logging a user in.
  """
  @spec log_in_changeset(attrs()) :: %Changeset{}
  def log_in_changeset(%{} = attrs \\ %{}), do: User.log_in_changeset(attrs)

  ## Settings

  @doc """
  Return an `%Ecto.Changeset{}` for changing the user e-mail.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  @spec change_user_email(%User{}, attrs()) :: %Changeset{}
  def change_user_email(%User{} = user, %{} = attrs \\ %{}) do
    User.email_changeset(user, attrs, [validate_unique_email: false])
  end

  @doc """
  Emulate that the e-mail will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  @spec apply_user_email(%User{}, String.t(), attrs()) ::
          {:ok, %User{}} | {:error, %Changeset{}}
  def apply_user_email(%User{} = user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.update_change(:email, &trim_downcase/1)
    |> Ecto.Changeset.apply_action(:update)
    |> case do
      {:ok, applied_user} ->
        {:ok, applied_user}

      {:error, set} ->
        # Reset `:email` to its initial untrimmed value.
        {:error, put_changes_from_attrs(set, attrs, [:email])}
    end
  end

  @doc """
  Update a user after editing via `CloudDbUiWeb.UserLive.FormComponent`
  as an admin.
  """
  @spec update_user(%User{}, attrs()) ::
          {:ok, %User{}} | {:error, %Changeset{}}
  def update_user(%User{} = user, attrs \\ %{}) do
    user
    |> User.saving_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Update the user e-mail using the given token.

  If the token matches, the user e-mail is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  @spec update_user_email(%User{}, String.t()) :: :ok | :error
  def update_user_email(%User{} = user, token) do
    context = "change:#{user.email}"
    result = UserToken.verify_change_email_token_query(token, context)

    with {:ok, query} <- result,
         %UserToken{sent_to: mail} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, mail, context)) do
      :ok
    else
      _ -> :error
    end
  end

  @doc """
  Increase the value of a `%User{}`'s `:balance`.
  """
  @spec top_up_user_balance(%User{}, attrs()) ::
          {:ok, %User{}} | {:error, %Changeset{}}
  def top_up_user_balance(%User{} = user, attrs) do
    user
    |> top_up_changeset(attrs)
    |> Repo.update()
  end

  @spec top_up_changeset(%User{}, attrs()) :: %Changeset{}
  def top_up_changeset(%User{} = user, attrs \\ %{}) do
    User.top_up_changeset(user, attrs)
  end

  @spec payment_changeset(%User{}, attrs()) :: %Changeset{}
  def payment_changeset(%User{} = user, attrs \\ %{}) do
    User.payment_changeset(user, attrs)
  end

  @doc """
  Only call `Repo.update()` on a passed user change`set`.

  Changeset validity check happens outside in
  `CloudDbUiWeb.OrderLive.PayComponent.pay_for_order()`.
  """
  @spec spend_user_balance(%Changeset{}) ::
          {:ok, %User{}} | {:error, %Changeset{}}
  def spend_user_balance(%Changeset{} = set), do: Repo.update(set)

  @doc ~S"""
  Deliver the update e-mail instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_user_update_email_instructions(
          %User{},
          String.t(),
          (String.t() -> String.t())
        ) :: {:ok, %{} | %Swoosh.Email{}}
  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        fn_update_email_url
      ) when is_function(fn_update_email_url, 1) do
    {encoded_token, user_token} =
      UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)

    UserNotifier.deliver_update_email_instructions(
      user,
      fn_update_email_url.(encoded_token)
    )
  end

  @doc """
  Return an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  @spec change_user_password(%User{}, attrs()) :: %Changeset{}
  def change_user_password(%User{} = user, attrs \\ %{}) do
    User.password_changeset(user, attrs, [hash_password: false])
  end

  @doc """
  Update the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_user_password(%User{}, String.t(), attrs()) ::
          {:ok, %User{}} | {:error, %Changeset{}}
  def update_user_password(%User{} = user, current_password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(current_password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(
      :tokens,
      UserToken.by_user_and_contexts_query(user, :all)
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generate a session token.
  """
  @spec generate_user_session_token(%User{}) :: binary()
  def generate_user_session_token(%User{} = user) do
    {token, user_token} = UserToken.build_session_token(user)

    Repo.insert!(user_token)

    token
  end

  @doc """
  Get the user with the given signed token.
  """
  @spec get_user_by_session_token(binary() | nil) :: %User{} | nil
  def get_user_by_session_token(nil), do: nil

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.one(query)
  end

  @doc """
  Delete a user.
  """
  @spec delete_user(%User{}) :: {:ok, %User{}} | {:error, %Changeset{}}
  def delete_user(%User{} = user) do
    user
    |> User.deletion_changeset()
    |> Repo.delete()
  end

  @doc """
  Delete the signed token with the given context.
  """
  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    token
    |> UserToken.by_token_and_context_query("session")
    |> Repo.delete_all()

    :ok
  end

  ## Confirmation

  @doc ~S"""
  Deliver the confirmation e-mail instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed, &url(~p"/confirm_email/#{&1}"))
      {:error, :already_confirmed}

  """
  @spec deliver_user_confirmation_instructions(
          %User{},
          (String.t() -> String.t())
        ) :: {:ok, %{} | %Swoosh.Email{}}
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} =
        UserToken.build_email_token(user, "confirm")

      Repo.insert!(user_token)

      UserNotifier.deliver_confirmation_instructions(
        user,
        confirmation_url_fun.(encoded_token)
      )
    end
  end

  @doc """
  Confirm a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  ## Reset password

  @doc ~S"""
  Deliver a reset password e-mail to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")

    Repo.insert!(user_token)

    UserNotifier.deliver_reset_password_instructions(
      user,
      reset_password_url_fun.(encoded_token)
    )
  end

  @doc """
  Get the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  @spec get_user_by_reset_password_token(String.t()) :: %User{} | nil
  def get_user_by_reset_password_token(token) do
    result = UserToken.verify_email_token_query(token, "reset_password")

    with {:ok, query} <- result,
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Reset the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "Test123.", password_confirmation: "Test123."})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "Test123.", password_confirmation: "_"})
      {:error, %Ecto.Changeset{}}

  """
  @spec reset_user_password(%User{}, attrs()) ::
          {:ok, %User{}} | {:error, %Changeset{}}
  def reset_user_password(%User{} = user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(
      :tokens,
      UserToken.by_user_and_contexts_query(user, :all)
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @spec user_email_multi(%User{}, String.t(), String.t()) :: %Ecto.Multi{}
  defp user_email_multi(%User{} = user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirmation_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(
      :tokens,
      UserToken.by_user_and_contexts_query(user, [context])
    )
  end

  @spec confirm_user_multi(%User{}) :: %Ecto.Multi{}
  defp confirm_user_multi(%User{} = user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirmation_changeset(user))
    |> Ecto.Multi.delete_all(
      :tokens,
      UserToken.by_user_and_contexts_query(user, ["confirm"])
    )
  end
end
