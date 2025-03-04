defmodule CloudDbUi.Accounts.User do
  use Ecto.Schema

  import CloudDbUi.Accounts.User.FlopSchemaFields
  import CloudDbUi.Changeset
  import CloudDbUiWeb.Utilities
  import Ecto.Changeset

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders.Order
  alias Ecto.Changeset

  @type attrs :: CloudDbUi.Type.attrs()

  @balance_limit Decimal.new("3000000.00")
  @top_up_amount_limit Decimal.new("1000000.00")
  @email_pattern ~r/^[a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z0-9.\-]+$/

  # TODO: a unique username for the user (with a limited character count)?

  @derive {
    Flop.Schema,
    filterable: filterable_fields(),
    sortable: sortable_fields(),
    adapter_opts: adapter_opts(),
    default_limit: 25,
    max_limit: 100,
    default_order: %{order_by: [:id], order_directions: [:asc]}
  }

  schema("users") do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime
    field :balance, :decimal, default: Decimal.new("0.00")
    field :top_up_amount, :decimal, virtual: true, default: Decimal.new("5.00")
    field :admin, :boolean, redact: true, default: false
    field :active, :boolean, redact: true, default: true
    has_many :orders, Order, preload_order: [desc: :paid_at]
    field :paid_orders, :integer, virtual: true

    timestamps([type: :utc_datetime])
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_unique_email` - Validates the uniqueness of the email.
      If you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  @spec registration_validation_changeset(%User{}, attrs(), keyword()) ::
          %Changeset{}
  def registration_validation_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    # Skipping `cast()`, because `cast()` does not add passwords
    # consisting only of spaces to `:changes`.
    |> maybe_put_password(attrs)
    |> validate_email(opts)
    |> validate_password(opts)
    |> maybe_validate_confirmation(:password, [required: true])
    # Reset `:email` to its initial untrimmed value.
    |> put_changes_from_attrs(attrs, [:email])
  end

  @spec registration_saving_changeset(%User{}, attrs(), keyword()) ::
          %Changeset{}
  def registration_saving_changeset(%User{} = user, attrs, opts \\ []) do
    user
    |> registration_validation_changeset(attrs, opts)
    |> case do
      %{valid?: true} = valid_set ->
        cast_transformed(valid_set, attrs, [:email], &trim_downcase/1)

      %{valid?: false} = invalid_set ->
        invalid_set
    end
  end

  @doc """
  A changeset for seeding the data base. `cast()`s additional
  properties.
  """
  @spec creation_changeset(attrs()) :: %Changeset{}
  def creation_changeset(attrs) do
    %User{}
    |> saving_changeset(attrs)
    |> cast(attrs, [:admin, :active])
  end

  @doc """
  A changeset for validation when creating or editing a user
  as an admin.
  """
  @spec validation_changeset(
          %User{},
          attrs(),
          boolean(),
          [String.t()] | nil
        ) :: %Changeset{}
  def validation_changeset(
        %User{} = user,
        attrs,
        validate_unique? \\ true,
        target \\ nil
      ) do
    attrs_new =
      attrs
      |> Map.replace_lazy("email_confirmation", &trim_downcase/1)
      |> maybe_replace_confirmed_at()

    user
    |> cast(attrs_new, [:active, :confirmed_at])
    # Not in `cast()`, because `cast()` does not add passwords
    # consisting only of spaces to `:changes`.
    |> maybe_put_password(attrs_new)
    |> cast_transformed(attrs_new, [:email], &trim_downcase/1)
    |> cast_transformed(attrs_new, [:balance], &trim/1)
    |> validate_required([:active])
    |> validate_required_with_default([:balance])
    # Contains `validate_required([:email])`.
    |> validate_email([validate_unique_email: false])
    |> maybe_validate_confirmation(:email, [required: true, target: target])
    |> maybe_unsafe_validate_unique_constraint(:email, validate_unique?)
    # Contains `validate_required([:password])`.
    |> maybe_validate_password(user, [hash_password: false])
    |> maybe_validate_confirmation(:password, [required: true, target: target])
    |> maybe_validate_format_decimal(:balance)
    |> maybe_validate_format_not_negative_zero(:balance)
    |> maybe_validate_zero_admin_balance(user)
    |> validate_sign(:balance, [sign: :non_negative])
    |> validate_number(:balance, [less_than_or_equal_to: @balance_limit])
    |> validate_change(:confirmed_at, &validator_not_in_the_far_past/2)
    |> validate_change(:confirmed_at, &validator_not_in_the_future/2)
    # Reset `:balance` and `:email` to their initial untrimmed value.
    |> put_changes_from_attrs(attrs_new, [:email, :balance])
    # Reset `:email_confirmation` to its initial untrimmed value.
    |> cast(attrs, [])
  end

  @doc """
  `validation_changeset()` with extra steps.
  """
  @spec saving_changeset(%User{}, attrs()) :: %Changeset{}
  def saving_changeset(%User{} = user, attrs) do
    user
    |> validation_changeset(attrs, true)
    |> case do
      %{valid?: true} = valid_set ->
        valid_set
        |> cast_transformed(attrs, [:balance], &trim/1)
        |> update_changes([:balance], &Decimal.round(&1, 2))
        |> cast_transformed(attrs, [:email], &trim_downcase/1)
        |> maybe_hash_password([hash_password: true])

      %{valid?: false} = invalid_set ->
        invalid_set
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  @spec email_changeset(%User{}, attrs(), keyword(boolean())) :: %Changeset{}
  def email_changeset(%User{} = user, attrs, opts \\ []) do
    user
    |> cast_transformed(attrs, [:email], &trim_downcase/1)
    |> validate_email(opts)
    |> validate_no_change(:email)
    # Reset `:email` to its initial untrimmed value.
    |> put_changes_from_attrs(attrs, [:email])
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  @spec password_changeset(%User{}, attrs(), keyword(boolean())) ::
          %Changeset{}
  def password_changeset(%User{} = user, attrs, opts \\ []) do
    user
    |> cast(attrs, [])
    # Skipping `cast()`, because `cast()` does not add passwords
    # consisting only of spaces to `:changes`.
    |> maybe_put_password(attrs)
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  A user changeset for topping up `:balance`.
  """
  @spec top_up_changeset(%User{}, attrs()) :: %Changeset{}
  def top_up_changeset(%User{} = user, attrs) do
    user
    # Forcing changes, because `:top_up_amount` is always a delta.
    |> cast_transformed(
      attrs,
      [:top_up_amount],
      &trim/1,
      force_changes: true
    )
    |> validate_required_with_default([:top_up_amount])
    |> maybe_validate_format_decimal(:top_up_amount)
    |> validate_number(
      :top_up_amount,
      greater_than_or_equal_to: user.top_up_amount
    )
    |> validate_number(
      :top_up_amount,
      less_than_or_equal_to: @top_up_amount_limit
    )
    |> maybe_put_balance(user)
    |> maybe_validate_zero_admin_balance(user)
    |> validate_top_up_balance_limit()
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    # No need to change `:top_up_amount` in a `%User{}`.
    |> delete_change(:top_up_amount)
  end

  @doc """
  A user changeset for finalising orders (paying for them).
  """
  @spec payment_changeset(%User{}, attrs()) :: %Changeset{}
  def payment_changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> validate_number(:balance, less_than_or_equal_to: user.balance)
    |> validate_number(:balance, greater_than_or_equal_to: 0)
  end

  @doc """
  Confirm the account by setting `confirmed_at`.
  """
  @spec confirmation_changeset(%User{} | %Changeset{}) :: %Changeset{}
  def confirmation_changeset(user) do
    change(user, [confirmed_at: DateTime.utc_now(:second)])
  end

  @doc """
  A user changeset for deletion. Invalid if any condition is true:

    - the `user` is an admin;
    - the `user` has positive `:balance`.
    - the `user` has any paid orders.
  """
  @spec deletion_changeset(%User{}) :: %Changeset{}
  def deletion_changeset(%User{admin: false, paid_orders: 0} = user) do
    if Decimal.compare(user.balance, "0") == :eq do
      change(user)
    else
      user
      |> change()
      |> add_error(
        :balance,
        "the user has positive balance",
        [validation: :balance_zero]
      )
    end
  end

  def deletion_changeset(%User{admin: true} = user) do
    user
    |> change()
    |> add_error(
      :admin,
      "the user is an administrator",
      [validation: :admin_not]
    )
  end

  # The value of `:paid_orders` is `nil` or greater than zero.
  def deletion_changeset(%User{} = user) do
    user
    |> change()
    |> add_error(
      :paid_orders,
      "the user has a paid order",
      [validation: :paid_orders_zero]
    )
  end

  @doc """
  A user changeset for logging in.
  """
  @spec log_in_changeset(attrs()) :: %Changeset{}
  def log_in_changeset(%{} = attrs) do
    %User{}
    |> cast(attrs, [:email, :password])
    # Skipping `cast()`, because `cast()` does not add passwords
    # consisting only of spaces to `:changes`.
    |> maybe_put_password(attrs)
    |> validate_required([:password])
    |> validate_length(:password, [min: 8, max: 72])
    |> validate_email([validate_unique_email: false])
    # Reset `:email` to its initial untrimmed value.
    |> put_changes_from_attrs(attrs, [:email])
  end

  @doc """
  Verify the password.

  If there is no user, or the user doesn't have a password, call
  `Pbkdf2.no_user_verify/0` to avoid timing attacks.
  """
  @spec valid_password?(%User{}, String.t()) :: boolean()
  def valid_password?(%User{hashed_password: hashed}, password)
      when is_binary(hashed) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()

    false
  end

  @doc """
  If the change`set` is valid, validates the current `pass`word.
  If the `pass`word is invalid, adds an "is not valid" error
  to the change`set`.
  """
  @spec validate_current_password(%Changeset{}, String.t()) :: %Changeset{}
  def validate_current_password(%Changeset{} = set, pass) do
    changeset_new = cast(set, %{current_password: pass}, [:current_password])

    cond do
      !changeset_new.valid? -> changeset_new
      valid_password?(changeset_new.data, pass) -> changeset_new
      true -> add_error(changeset_new, :current_password, "is not valid")
    end
  end

  @doc """
  E-mail address validity check.
  """
  @spec valid_email?(String.t()) :: boolean()
  def valid_email?(e_mail) do
    String.length(e_mail) <= 160 and Regex.match?(@email_pattern, e_mail)
  end

  @doc """
  Checks whether `id_or_e_mail` matches `user.id` or `user.email`.
  Expects a trimmed and down-cased value of `id_or_e_mail`.
  """
  @spec match_id_or_email?(String.t(), %User{} | nil) :: boolean()
  def match_id_or_email?(id_or_e_mail, user) do
    user && (id_or_e_mail == "#{user.id}" or id_or_e_mail == user.email)
  end

  @doc """
  Determine if a `%User{}` is an administrator.
  `nil` users are not administrators.
  """
  @spec admin?(%User{} | nil) :: boolean()
  def admin?(nil), do: false

  def admin?(%User{admin: admin} = _user), do: admin

  @doc """
  Determine whether an user is deletable (not an administrator,
  owns no `:paid_orders` and has zero `:balance`).
  """
  @spec deletable?(%User{}) :: boolean()
  def deletable?(%User{admin: true} = _user), do: false

  # Non-admin.
  def deletable?(%User{paid_orders: 0} = user) do
    Decimal.compare(user.balance, 0) == :eq
  end

  # `:paid_orders` is either `nil` or greater than zero,
  # or `:balance` is greater than zero.
  def deletable?(%User{} = _user), do: false

  @doc """
  A getter for accessing `@balance_limit` outside of the module.
  """
  @spec balance_limit() :: %Decimal{}
  def balance_limit(), do: @balance_limit

  @doc """
  A getter for accessing `@top_up_amount_limit` outside of the module.
  """
  @spec top_up_amount_limit() :: %Decimal{}
  def top_up_amount_limit(), do: @top_up_amount_limit

  @doc """
  Fill the `:paid_orders` virtual field.
  """
  @spec fill_paid_orders(%User{}) :: %User{}
  def fill_paid_orders(%User{} = user) when is_list(user.orders) do
    Map.replace(
      user,
      :paid_orders,
      Enum.count(user.orders, &(&1.paid_at != nil))
    )
  end

  # A valid change`set`, calculate a changed `:balance`.
  @spec maybe_put_balance(%Changeset{}, %User{}) :: %Changeset{}
  defp maybe_put_balance(%{changes: %{top_up_amount: amount}} = set, user)
       when set.valid? do
    put_change(set, :balance, Decimal.add(user.balance, amount))
  end

  # Errors in `changeset` or no change of `:top_up_amount`,
  # do not change `:balance`.
  defp maybe_put_balance(changeset, _user), do: changeset

  # Will call `unsafe_validate_unique()` and `unique_constraint()`,
  # unless `opts` contain `validate_unique_email: false`.
  @spec validate_email(%Changeset{}, keyword(boolean())) :: %Changeset{}
  defp validate_email(changeset, opts) do
    changeset
    |> update_change(:email, &trim/1)
    |> validate_required([:email])
    |> validate_format(
      :email,
      @email_pattern,
      message: "invalid e-mail format"
    )
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  # Put a change of `:hashed_password` and delete the change
  # of `:password`, unless `opts` contain `hash_password: false`.
  @spec validate_password(%Changeset{}, keyword(boolean())) :: %Changeset{}
  defp validate_password(%Changeset{} = changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(
      :password,
      ~r/[a-z]/,
      message: "at least one lower-case character"
    )
    |> validate_format(
      :password,
      ~r/[A-Z]/,
      message: "at least one upper-case character"
    )
    |> validate_format(
      :password,
      ~r/[!?,\.`~@#$%^&*\-_ 0-9{}\[\]()\/\\:;"'<>*+|]/,
      message: "at least one digit, space or punctuation character"
    )
    |> maybe_hash_password(opts)
  end

  # Put a change of `:hashed_password` and delete the change
  # of `:password`, unless `opts` contain `hash_password: false`
  # or the `changeset` is invalid.
  @spec maybe_hash_password(%Changeset{}, keyword(boolean())) :: %Changeset{}
  defp maybe_hash_password(%Changeset{} = changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`,
      # but that would keep the data base transaction open longer
      # and hurt performance.
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  # Will call `unsafe_validate_unique()` and `unique_constraint()`,
  # unless `opts` contain `validate_unique_email: false`.
  @spec maybe_validate_unique_email(%Changeset{}, keyword()) :: %Changeset{}
  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_unique_email, true) do
      changeset
      |> unsafe_validate_unique(:email, CloudDbUi.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  # `validate_zero_balance()` when there is a change of `:balance`
  # in change`set.changes` and the user is an admin (this means
  # there is `admin: true` or `"admin" => "true"` in `attrs`,
  # or `user.admin` is `true`).
  @spec maybe_validate_zero_admin_balance(%Changeset{}, %User{}) ::
          %Changeset{}
  defp maybe_validate_zero_admin_balance(
         %{changes: %{balance: _}} = set,
         %User{} = user
       ) do
    case Map.get(set.params, "admin") || user.admin do
      truthy when truthy in [true, "true"] -> validate_zero_balance(set)
      _any -> set
    end
  end

  # No change of `:balance` in change`set.changes`.
  defp maybe_validate_zero_admin_balance(set, %User{}), do: set

  @spec validate_zero_balance(%Changeset{}) :: %Changeset{}
  defp validate_zero_balance(%Changeset{changes: %{balance: balance}} = set) do
    validate_zero_balance(set, balance)
  end

  @spec validate_zero_balance(%Changeset{}, %Decimal{} | String.t()) ::
          %Changeset{}
  defp validate_zero_balance(%Changeset{} = changeset, %Decimal{} = balance) do
    if Decimal.compare(balance, 0) == :eq do
      changeset
    else
      add_error(
        changeset,
        :balance,
        "can't be non-zero for an admin",
        [validation: :zero_for_admin]
      )
    end
  end

  # If not a `%Decimal{}`, then `balance` is expected to be a string.
  defp validate_zero_balance(%Changeset{} = changeset, balance) do
    balance
    |> String.trim()
    |> parse_decimal()
    |> case do
      {%Decimal{} = parsed, ""} -> validate_zero_balance(changeset, parsed)
      _error_or_not_fully_parsed -> changeset
    end
  end

  # For cases when `:balance` is less then a `@top_up_amount_limit`
  # away from `@balance_limit`.
  @spec validate_top_up_balance_limit(%Changeset{}) :: %Changeset{}
  defp validate_top_up_balance_limit(%{changes: %{balance: balance}} = set) do
    until_limit = Decimal.sub(@balance_limit, balance)

    if until_limit.sign == -1 do
      add_error(
        set,
        :top_up_amount,
        top_up_balance_limit_validation_error_message(until_limit),
        [validation: :balance_limit]
      )
    else
      set
    end
  end

  # No change of `:balance` in `changeset.changes`.
  defp validate_top_up_balance_limit(changeset), do: changeset

  @spec top_up_balance_limit_validation_error_message(%Decimal{}) :: String.t()
  defp top_up_balance_limit_validation_error_message(until_limit) do
    Kernel.<>(
      "will exceed balance limit (PLN #{format(@balance_limit)}) by PLN ",
      format(Decimal.negate(until_limit))
    )
  end

  # `validate_password()` if there is a change of `:password`,
  # or if the `user` is a newly-created one.
  @spec maybe_validate_password(%Changeset{}, %User{}, keyword(boolean())) ::
          %Changeset{}
  defp maybe_validate_password(changeset, %User{} = user, opts) do
    case user.id == nil or Map.has_key?(changeset.changes, :password) do
      true -> validate_password(changeset, opts)
      false -> changeset
    end
  end

  # Use after `cast()`, because `cast()` does not add passwords
  # consisting only of spaces to `:changes`.
  @spec maybe_put_password(%Changeset{}, attrs()) :: %Changeset{}
  defp maybe_put_password(changeset, attrs) do
    case get_attr(attrs, :password) do
      empty when empty in [nil, ""] -> changeset
      password -> put_change(changeset, :password, password)
    end
  end

  # When there is no input with `type="datetime-local"`,
  # put `"confirmed_at"` depending on the `:confirmed` check box value.
  @spec maybe_replace_confirmed_at(attrs()) :: attrs()
  defp maybe_replace_confirmed_at(attrs) do
    case Map.get(attrs, "confirmed") do
      "true" -> Map.put(attrs, "confirmed_at", DateTime.utc_now())
      "false" -> Map.put(attrs, "confirmed_at", nil)
      _any -> attrs
    end
  end
end
