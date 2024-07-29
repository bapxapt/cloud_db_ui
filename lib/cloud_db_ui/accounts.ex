defmodule CloudDbUi.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  import CloudDbUiWeb.Utilities

  alias CloudDbUi.Repo
  alias CloudDbUi.Accounts.{User, UserToken, UserNotifier}
  alias CloudDbUi.Accounts.User.Query

  @type db_id :: CloudDbUi.Type.db_id()
  @type attrs() :: CloudDbUi.Type.attrs()

  ## Database getters

  @doc """
  List all users. Replaces `:orders` with order count.
  Fills the `:paid_orders` virtual field.
  """
  @spec list_users_with_order_count() :: [%User{}]
  def list_users_with_order_count() do
    Query.with_order_count()
    |> Repo.all()
  end

  @doc """
  Get a single user. No preloads.
  """
  @spec get_user(db_id()) :: %User{} | nil
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Get a single user. No preloads.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Get a single user. Preloads `:orders`. Each order has preloaded
  `:suborders`, and each sub-order has a preloaded `:product`.
  """
  @spec get_user_with_order_suborder_products!(db_id()) :: %User{}
  def get_user_with_order_suborder_products!(id) do
    Query.with_preloaded_order_suborder_products()
    |> Repo.get!(id)
    |> fill_virtual_fields()
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
    Repo.get_by(User, email: e_mail)
  end

  @doc """
  Get a user by e-mail and password. No preloads.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(e_mail, password)
      when is_binary(e_mail) and is_binary(password) do
    user = Repo.get_by(User, email: e_mail)

    if User.valid_password?(user, password), do: user
  end

  @doc """
  Get a user by ID or by e-mail. No preloads.
  """
  @spec get_user_by_id_or_email(db_id()) :: %User{} | nil
  def get_user_by_id_or_email(id_or_email) do
    case valid_id?(id_or_email) do
      true -> get_user(id_or_email)
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
  def register_user(attrs, opts \\ []) do
    %User{}
    |> User.registration_saving_changeset(attrs, opts)
    |> Repo.insert()
  end

  @doc """
  Create a user (that can possibly be an administrator)
  while seeding the data base.
  """
  @spec create_user(attrs()) :: {:ok, %User{}} | {:error, %Ecto.Changeset{}}
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.creation_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Create a user as an admin.
  """
  @spec create_user(attrs(), atom()) ::
          {:ok, %User{}} | {:error, %Ecto.Changeset{}}
  def create_user(attrs, :via_form) do
    %User{}
    |> User.saving_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes
  when editing a user as an admin.
  """
  def change_user(
        %User{} = user,
        attrs \\ %{},
        validate_unique? \\ true,
        errors \\ []
      ) do
    User.validation_changeset(user, attrs, validate_unique?, errors)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes
  during the registration process.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_validation_changeset(
      user,
      attrs,
      [hash_password: false, validate_email: false]
    )
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user e-mail.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the e-mail will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Update a user after editing as an admin.
  """
  def update_user(%User{} = user, attrs \\ %{}) do
    user
    |> User.saving_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the user e-mail using the given token.

  If the token matches, the user e-mail is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  def top_up_user_balance(user, attrs) do
    user
    |> top_up_changeset(attrs)
    |> Repo.update()
  end

  def top_up_changeset(user, attrs \\ %{}) do
    User.top_up_changeset(user, attrs)
  end

  def payment_changeset(user, attrs \\ %{}) do
    User.payment_changeset(user, attrs)
  end

  @doc """
  Only calls `Repo.update()` on a passed change`set`.

  Changeset validity check happens outside in
  `CloudDbUiWeb.OrderLive.PayComponent.pay_for_order()`.
  """
  def spend_user_balance(%Ecto.Changeset{} = set), do: Repo.update(set)

  @doc ~S"""
  Delivers the update e-mail instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, [hash_password: false])
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)

    Repo.insert!(user_token)

    token
  end

  @doc """
  Get the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.one(query)
  end

  @doc """
  Delete a user.
  """
  def delete_user(%User{} = user), do: Repo.delete(user)

  @doc """
  Delete the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))

    :ok
  end

  ## Confirmation

  @doc ~S"""
  Deliver the confirmation e-mail instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

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
  Delivers the reset password e-mail to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
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
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirmation_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirmation_changeset(user))
    |> Ecto.Multi.delete_all(
      :tokens,
      UserToken.by_user_and_contexts_query(user, ["confirm"])
    )
  end

  @spec fill_virtual_fields([%User{}]) :: [%User{}]
  defp fill_virtual_fields(users) when is_list(users) do
    Enum.map(users, &fill_virtual_fields/1)
  end

  @spec fill_virtual_fields(%User{}) :: %User{}
  defp fill_virtual_fields(%User{} = user) when is_nil(user.paid_orders) do
    User.fill_paid_orders(user)
  end
end
