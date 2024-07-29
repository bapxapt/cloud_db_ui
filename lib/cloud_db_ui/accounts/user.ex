defmodule CloudDbUi.Accounts.User do
  use Ecto.Schema

  alias Ecto.Changeset
  alias CloudDbUi.Orders.Order

  import Ecto.Changeset
  import CloudDbUi.Changeset
  import CloudDbUiWeb.Utilities

  @type attrs :: CloudDbUi.Type.attrs()

  @balance_limit Decimal.new("3000000.00")
  @top_up_amount_limit Decimal.new("1000000.00")
  @email_pattern ~r/^[^\s]+@[^\s]+\.[^\s]+$/

  # TODO: a unique username for the user (with a limited character count)?

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime
    field :balance, :decimal, default: Decimal.new("0.00")
    field :top_up_amount, :decimal, virtual: true, default: Decimal.new("5.00")
    field :paid_orders, :integer, virtual: true
    field :admin, :boolean, redact: true, default: false
    field :active, :boolean, redact: true, default: true
    has_many :orders, Order

    timestamps(type: :utc_datetime)
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

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_validation_changeset(user, attrs, opts \\ []) do
    user
    |> registration_changeset(attrs, opts)
    |> maybe_validate_confirmation(:password, [required: true])
    # Reset `:email` to its initial untrimmed value.
    |> put_changes_from_attrs(attrs, [:email])
  end

  def registration_saving_changeset(user, attrs, opts \\ []) do
    user
    |> registration_validation_changeset(attrs, opts)
    |> cast_transformed_if_valid(attrs, [:email], &trim_downcase/1)
  end

  @doc """
  A changeset for seeding the data base. `cast()`s additional
  properties.
  """
  def creation_changeset(user, attrs, opts \\ []) do
    user
    |> registration_changeset(attrs, opts)
    |> cast(attrs, [:admin, :active, :balance])
  end

  @doc """
  A changeset for validation when creating or editing a user
  as an admin.
  """
  def validation_changeset(user, attrs, validate_unique?) do
    attrs_new =
      Map.replace_lazy(attrs, "email_confirmation", &trim_downcase/1)

    user
    |> cast(attrs_new, [:active, :confirmed_at])
    # Skipping `cast()`, because `cast()` does not add passwords
    # consisting only of spaces to `:changes`.
    |> maybe_put_password(attrs_new)
    |> cast_transformed(attrs_new, [:email], &trim_downcase/1)
    |> cast_transformed(attrs_new, [:balance], &trim/1)
    |> validate_required([:active, :balance])
    # Contains `validate_required([:email])`.
    |> validate_email(validate_email: false)
    |> maybe_validate_confirmation(:email, required: true)
    |> maybe_unsafe_validate_unique_constraint(:email, validate_unique?)
    # Contains `validate_required([:password])`.
    |> maybe_validate_password(user, hash_password: false)
    |> maybe_validate_confirmation(:password, required: true)
    |> maybe_validate_format_decimal(attrs_new, :balance)
    |> maybe_validate_format_not_negative_zero(attrs_new, :balance)
    |> validate_sign(:balance, sign: :non_negative)
    |> validate_number(:balance, less_than_or_equal_to: @balance_limit)
    |> validate_change(:confirmed_at, &validator_not_in_the_future/2)
    # Reset `:balance` and `:email` to their initial untrimmed value.
    |> put_changes_from_attrs(attrs_new, [:email, :balance])
    # Reset `:email_confirmation` to its initial untrimmed value.
    |> cast(attrs, [])
  end

  @doc """
  A changeset for saving when creating or editing a user
  as an admin. `validation_changeset()` with extra steps.
  """
  def saving_changeset(user, attrs) do
    user
    |> validation_changeset(attrs, true)
    |> cast_transformed_if_valid(attrs, [:balance], &trim/1)
    |> cast_transformed_if_valid(attrs, [:email], &trim_downcase/1)
    |> maybe_hash_password(hash_password: true)
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast_transformed(attrs, [:email], &trim_downcase/1)
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
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
  def password_changeset(user, attrs, opts \\ []) do
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
  def top_up_changeset(user, attrs) do
    user
    # Forcing changes, because `:top_up_amount` is always a delta.
    |> cast_transformed(
      attrs,
      [:top_up_amount],
      &trim/1,
      force_changes: true
    )
    |> validate_required_top_up_amount(attrs)
    |> maybe_validate_format_decimal(attrs, :top_up_amount)
    |> validate_number(
      :top_up_amount,
      greater_than_or_equal_to: user.top_up_amount
    )
    |> validate_number(
      :top_up_amount,
      less_than_or_equal_to: @top_up_amount_limit
    )
    |> maybe_put_balance(user)
    |> validate_top_up_balance_limit()
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    # Reset `:top_up_amount` to its initial untrimmed value.
    |> put_changes_from_attrs(attrs, [:top_up_amount])
  end

  @doc """
  A user changeset for paying.
  """
  def payment_changeset(user, attrs) do
    user
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> validate_number(:balance, less_than_or_equal_to: user.balance)
    |> validate_number(:balance, greater_than_or_equal_to: 0)
  end

  @doc """
  Confirm the account by setting `confirmed_at`.
  """
  def confirmation_changeset(user) do
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    change(user, confirmed_at: now)
  end

  @doc """
  Verify the password.

  If there is no user, or the user doesn't have a password, call
  `Pbkdf2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed}, password)
      when is_binary(hashed) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()

    false
  end

  @doc """
  Validates the current password, otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset =
      cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
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
  @spec match_id_or_email?(String.t(), %__MODULE__{} | nil) :: boolean()
  def match_id_or_email?(id_or_e_mail, user) do
    user && (id_or_e_mail == "#{user.id}" or id_or_e_mail == user.email)
  end

  @doc """
  Determine if a `%User{}` is an administrator.
  `nil` users are not administrators.
  """
  @spec admin?(%__MODULE__{} | nil) :: boolean()
  def admin?(nil), do: false

  def admin?(user), do: user.admin

  @doc """
  Determine whether an user is deletable (not an administrator,
  owns no `:paid_orders` and has zero `:balance`).
  """
  @spec deletable?(%__MODULE__{}) :: boolean()
  def deletable?(%__MODULE__{admin: true} = _user), do: false

  def deletable?(%__MODULE__{} = user) when is_integer(user.paid_orders) do
    user.paid_orders == 0 and Decimal.compare(user.balance, 0) != :gt
  end

  # `:paid_orders` is either `nil` or greater than zero,
  # or `:balance` is greater than zero.
  def deletable?(%__MODULE__{} = _user), do: false

  @doc """
  A getter for accessing `@balance_limit` outside of the module.
  """
  def balance_limit(), do: @balance_limit

  @doc """
  A getter for accessing `@top_up_amount_limit` outside of the module.
  """
  def top_up_amount_limit(), do: @top_up_amount_limit

  @doc """
  Fill the `:paid_orders` virtual field.
  """
  @spec fill_paid_orders(%__MODULE__{}) :: %__MODULE__{}
  def fill_paid_orders(%__MODULE__{} = user) when is_list(user.orders) do
    Map.replace(
      user,
      :paid_orders,
      Enum.count(user.orders, &(&1.paid_at != nil))
    )
  end

  # The base for other seeding or registration changesets.
  @spec registration_changeset(%__MODULE__{}, attrs(), keyword()) ::
          %Changeset{}
  defp registration_changeset(user, attrs, opts) do
    user
    |> cast(attrs, [:email])
    # Skipping `cast()`, because `cast()` does not add passwords
    # consisting only of spaces to `:changes`.
    |> maybe_put_password(attrs)
    |> validate_email(opts)
    |> validate_password(opts)
  end

  # Cannot use standard `validate_required()`, because it finds
  # a default value and does not put a "can't be blank" error
  # if the input field is blank.
  @spec validate_required_top_up_amount(%Changeset{}, attrs()) :: %Changeset{}
  defp validate_required_top_up_amount(%Changeset{} = set, attrs) do
    if trim(get_attr(attrs, :top_up_amount)) in ["", nil] do
      add_error(set, :top_up_amount, "can't be blank", validation: :required)
    else
      set
    end
  end

  # A valid change`set`, calculate a changed `:balance`.
  @spec maybe_put_balance(%Changeset{}, %__MODULE__{}) :: %Changeset{}
  defp maybe_put_balance(%{changes: %{top_up_amount: amount}} = set, user)
       when set.valid? do
    put_change(set, :balance, Decimal.add(user.balance, amount))
  end

  # Errors in `changeset` or no change of `:top_up_amount`,
  # do not change `:balance`.
  defp maybe_put_balance(changeset, _user), do: changeset

  # Will call `unsafe_validate_unique()` and `unique_constraint()`,
  # unless `opts` contain `validate_email: false`.
  defp validate_email(changeset, opts) do
    changeset
    |> update_change(:email, &trim/1)
    |> validate_required([:email])
    |> validate_format(
      :email,
      @email_pattern,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  # Will put a change of `:hashed_password` and delete the change
  # of `:password`, unless `opts` contain `hash_password: false`.
  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(
      :password,
      ~r/[a-z]/,
      message: "at least one lower case character"
    )
    |> validate_format(
      :password,
      ~r/[A-Z]/,
      message: "at least one upper case character"
    )
    |> validate_format(
      :password,
      ~r/[!?,\.`~@#$%^&*-_ 0-9]/,
      message: "at least one digit, space or punctuation character"
    )
    |> maybe_hash_password(opts)
  end

  # Will put a change of `:hashed_password` and delete the change
  # of `:password`, unless `opts` contain `hash_password: false`.
  defp maybe_hash_password(changeset, opts) do
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
  # unless `opts` contain `validate_email: false`.
  @spec maybe_validate_unique_email(%Changeset{}, keyword()) :: %Changeset{}
  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, CloudDbUi.Repo)
      |> unique_constraint(:email)
    else
      changeset
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
        validation: :balance_limit
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
  defp maybe_validate_password(changeset, user, opts) do
    if user.id == nil or Map.has_key?(changeset.changes, :password) do
      validate_password(changeset, opts)
    else
      changeset
    end
  end

  # Use after `cast()`, because `cast()` does not add passwords
  # consisting only of spaces to `:changes`.
  @spec maybe_put_password(%Changeset{}, attrs()) :: %Changeset{}
  defp maybe_put_password(changeset, attrs) do
    case get_attr(attrs, :password) do
      blank when blank in [nil, ""] -> changeset
      password -> put_change(changeset, :password, password)
    end
  end
end
