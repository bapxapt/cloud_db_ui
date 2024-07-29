defmodule CloudDbUi.Changeset do
  alias Ecto.Changeset

  @type attrs() :: CloudDbUi.Type.attrs()
  @type error() :: CloudDbUi.Type.error()
  @type errors() :: CloudDbUi.Type.errors()

  @doc """
  `update_change()` for multiple fields.
  """
  @spec update_changes(%Changeset{}, [atom()], (any() -> any())) ::
          %Changeset{}
  def update_changes(%Changeset{} = changeset, fields, fn_update) do
    Enum.reduce(fields, changeset, fn field, acc ->
      Changeset.update_change(acc, field, fn_update)
    end)
  end

  @doc """
  `update_change()` for multiple fields if the `changeset` is valid.
  """
  @spec update_changes_if_valid(%Changeset{}, [atom()], (any() -> any())) ::
          %Changeset{}
  def update_changes_if_valid(%Changeset{} = changeset, fields, fn_update)
      when changeset.valid? do
    update_changes(changeset, fields, fn_update)
  end

  def update_changes_if_valid(changeset, _fields, _fn_update), do: changeset

  @doc """
  `validate_length()` for multiple fields.
  """
  @spec validate_lengths(%Changeset{}, %{atom() => keyword()}) ::
          %Changeset{}
  def validate_lengths(%Changeset{} = changeset, field_opts) do
    Enum.reduce(field_opts, changeset, fn {field, opts}, acc ->
      Changeset.validate_length(acc, field, opts)
    end)
  end

  @doc """
  Validate the sign of a `%Decimal{}`. Accepted options in `opts`:

    - `sign: :non_negative` or `sign: :negative`;
    - `message: "your error message here"`.

  Default messages: `"must not be negative"` for `sign: :non_negative`,
  and `"must be negative"` for `sign: :negative`.
  """
  @spec validate_sign(%Changeset{}, atom(), keyword()) :: %Changeset{}
  def validate_sign(changeset, field, opts) when is_atom(field) do
    Changeset.validate_change(
      changeset,
      field,
      &decimal_sign_validator(&1, &2, opts)
    )
  end

  @doc """
  Validate decimal format, if there is no error corresponding
  to a passed `field`.
  """
  @spec maybe_validate_format_decimal(
          %Changeset{},
          attrs(),
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  def maybe_validate_format_decimal(changeset, attrs, field, digits \\ 2) do
    case Keyword.has_key?(changeset.errors, field) do
      true -> changeset
      false -> validate_format_decimal(changeset, attrs, field, digits)
    end
  end

  @doc """
  Validate absence of a negative zero, if there is no error corresponding
  to a passed `field`.
  """
  @spec maybe_validate_format_not_negative_zero(
          %Changeset{},
          attrs(),
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  def maybe_validate_format_not_negative_zero(
        set,
        attrs,
        field,
        digits \\ 2
      ) do
    case Keyword.has_key?(set.errors, field) do
      true -> set
      false -> validate_format_not_negative_zero(set, attrs, field, digits)
    end
  end

  @doc """
  Validate unique constraints if a change for `field`
  is in `changeset.changes`.
  """
  @spec maybe_unsafe_validate_unique_constraint(
          %Changeset{},
          atom(),
          boolean()
        ) :: %Changeset{}
  def maybe_unsafe_validate_unique_constraint(set, field, true) do
    case Map.has_key?(set.changes, field) do
      false -> set
      true -> unsafe_validate_unique_constraints(set, [field])
    end
  end

  def maybe_unsafe_validate_unique_constraint(set, _field, false), do: set

  @doc """
  `unsafe_validate_unique()` plus `unique_constraint()`
  for multiple fields. Default options for both calls.
  """
  @spec unsafe_validate_unique_constraints(%Changeset{}, [atom()]) ::
          %Changeset{}
  def unsafe_validate_unique_constraints(%Changeset{} = set, fields) do
    Enum.reduce(fields, set, fn field, acc ->
      acc
      |> Changeset.unsafe_validate_unique(field, CloudDbUi.Repo)
      |> Changeset.unique_constraint(field)
    end)
  end

  @doc """
  Add a unique constraint violation error without calling
  `unsafe_validate_unique_constraints()`.
  """
  @spec add_unique_constraint_error(%Changeset{}, atom(), String.t()) ::
          %Changeset{}
  def add_unique_constraint_error(
        %Changeset{} = changeset,
        field,
        message \\ "has already been taken"
      ) do
    {^message, additional_info} = unique_constraint_error(field, message)

    Changeset.add_error(changeset, field, message, additional_info)
  end

  @doc """
  Return a unique constraint ("has already been taken") error.
  """
  @spec unique_constraint_error(atom(), String.t()) :: error()
  def unique_constraint_error(field, message \\ "has already been taken") do
    {message, [validation: :unsafe_unique, fields: [field]]}
  end

  @doc """
  `validate_confirmation()` of a `field` if there is a change
  corresponding to the `field` in `changeset.changes`.
  """
  @spec maybe_validate_confirmation(%Changeset{}, atom(), keyword()) ::
          %Changeset{}
  def maybe_validate_confirmation(changeset, field, opts \\ []) do
    if Map.has_key?(changeset.changes, field) do
      Changeset.validate_confirmation(changeset, field, opts)
    else
      changeset
    end
  end

  @doc """
  Transform `fields` before attempting to `cast()`. Transforming
  the values of `fields` with `&CloudDbUiWeb.Utilities.trim/1`
  allows to avoid an `"is invalid"` error when an extra space
  is in an input field.
  """
  @spec cast_transformed(
          struct(),
          attrs(),
          [atom()],
          (any() -> any()),
          keyword()
        ) :: %Changeset{}
  def cast_transformed(data_or_set, attrs, fields, fn_transform, opts \\ []) do
    attrs_new =
      attrs
      # In case `attrs` have atom keys.
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.take(Enum.map(fields, &to_string/1))
      |> Map.new(fn {key, value} -> {key, fn_transform.(value)} end)

    Changeset.cast(data_or_set, attrs_new, fields, opts)
  end

  @doc """
  `cast_transformed()` if the `changeset` is valid.
  """
  @spec cast_transformed_if_valid(
          %Changeset{},
          attrs(),
          [atom()],
          (any() -> any())
        ) :: %Changeset{}
  def cast_transformed_if_valid(set, attrs, fields, fn_transformed) do
    cast_transformed_if_valid(set, attrs, fields, fn_transformed, [])
  end

  @spec cast_transformed_if_valid(
          %Changeset{},
          attrs(),
          [atom()],
          (any() -> any()),
          keyword()
        ) :: %Changeset{}
  def cast_transformed_if_valid(set, attrs, fields, fn_transformed, opts)
      when set.valid? do
    cast_transformed(set, attrs, fields, fn_transformed, opts)
  end

  def cast_transformed_if_valid(set, _attrs, _fields, _fn, _opts), do: set

  # Restore the initial value of `fields` if they are contained
  # in `attrs`. Useful for restoring the value of attributes cast
  # with `cast_transformed()`.
  @spec put_changes_from_attrs(%Changeset{}, attrs(), [atom()]) :: %Changeset{}
  def put_changes_from_attrs(changeset, attrs, fields) do
    Enum.reduce(fields, changeset, &put_change_from_attrs(&2, attrs, &1))
  end

  @doc """
  Ensures `%DateTime{}`s in the future are not allowed.
  """
  @spec validator_not_in_the_future(atom(), %DateTime{}) :: errors()
  def validator_not_in_the_future(field, value) do
    DateTime.utc_now()
    |> DateTime.compare(value)
    |> case do
      :lt -> [{field, in_the_future_error()}]
      _gt_or_eq -> []
    end
  end

  @doc """
  Get a value from `attrs`, where a key can be a string or an atom.
  """
  @spec get_attr(attrs(), atom()) :: any()
  def get_attr(attrs, key) do
    cond do
      Map.has_key?(attrs, to_string(key)) -> attrs[to_string(key)]
      Map.has_key?(attrs, key) -> attrs[key]
      true -> nil
    end
  end

  @doc """
  Check existence of a key in `attrs`, where a key can be a string
  or an atom.
  """
  @spec has_attr?(attrs(), atom()) :: boolean()
  def has_attr?(attrs, key) do
    Map.has_key?(attrs, key) or Map.has_key?(attrs, to_string(key))
  end

  @doc """
  Get errors corresponding to `fields` as a map of error lists
  from an `%Ecto.Changeset{}` or from a `%Phoenix.HTML.Form{}`.
  """
  @spec get_errors(%Changeset{} | %Phoenix.HTML.Form{}, [atom()]) ::
          %{atom() => [{String.t, keyword()}]}
  def get_errors(changeset_or_form, fields) do
    fields
    |> Enum.filter(&Keyword.has_key?(changeset_or_form.errors, &1))
    |> Map.new(fn field ->
      {field, Keyword.get_values(changeset_or_form.errors, field)}
    end)
  end

  @spec in_the_future_error() :: error()
  defp in_the_future_error() do
    {"can't be in the future", [validation: :not_in_the_future]}
  end

  # The `value` is a `%Decimal{}`, get the `:sign` option.
  @spec decimal_sign_validator(atom(), %Decimal{}, keyword()) ::
          [{atom(), {String.t, keyword()}}]
  defp decimal_sign_validator(field, value, opts) when is_list(opts) do
    decimal_sign_validator(field, value, opts[:sign], opts[:message])
  end

  @spec decimal_sign_validator(atom(), %Decimal{}, atom(), String.t() | nil) ::
          [{atom(), {String.t, keyword()}}]
  defp decimal_sign_validator(field, %Decimal{} = value, :non_negative, msg) do
    case value.sign do
      -1 -> [{field, {msg || "must not be negative", [validation: :sign]}}]
      _any -> []
    end
  end

  defp decimal_sign_validator(field, %Decimal{} = value, :negative, msg) do
    case value.sign do
      1 -> [{field, {msg || "must be negative", [validation: :sign]}}]
      _any -> []
    end
  end

  # The `value` is not a `%Decimal{}`, and/or `opts[:sign]`
  # is neither `:non_negative` nor `:negative`, do not validate.
  defp decimal_sign_validator(_field, _value, _sign_opt, _msg), do: []

  # Restore the initial value of a `field` if it is contained in `attrs`.
  @spec put_change_from_attrs(%Changeset{}, attrs(), atom()) :: %Changeset{}
  defp put_change_from_attrs(%Changeset{} = set, attrs, field) do
    cond do
      !has_attr?(attrs, field) -> set
      true -> Changeset.put_change(set, field, get_attr(attrs, field))
    end
  end

  # `validate_format()` for a decimal (`inputmode="decimal"`) field,
  # ensuring valid number format. Gets the value from `attrs`.
  @spec validate_format_decimal(
          %Changeset{},
          attrs() | String.t(),
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  defp validate_format_decimal(%Changeset{} = set, attrs, field, digits)
       when is_map(attrs) do
    if has_attr?(attrs, field) do
      validate_format_decimal(set, get_attr(attrs, field), field, digits)
    else
      set
    end
  end

  # The `value` is a string, validate.
  # Spaces before and/or after a `value` do not affect validity.
  defp validate_format_decimal(%Changeset{} = set, value, field, digits)
       when is_binary(value) do
    value
    |> String.trim()
    |> CloudDbUiWeb.Utilities.valid_number_format?(digits)
    |> if do
      set
    else
      Changeset.add_error(
        set,
        field,
        decimal_format_error_message(digits),
        [validation: :format_decimal]
      )
    end
  end

  # The `value` is not a string, do not validate.
  defp validate_format_decimal(%Changeset{} = set, _value, _field, _), do: set

  @spec decimal_format_error_message(non_neg_integer()) :: String.t()
  defp decimal_format_error_message(digits) do
    """
    invalid format; valid examples: 5, 7.9, 12.#{String.duplicate("9", digits)}
    """
  end

  # `validate_format()` for a decimal (`inputmode="decimal"`) field,
  # ensuring absence of a negative zero. Gets the value from `attrs`.
  @spec validate_format_not_negative_zero(
          %Changeset{},
          attrs() | String.t(),
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  defp validate_format_not_negative_zero(set, attrs, field, digits)
       when is_map(attrs) do
    if has_attr?(attrs, field) do
      validate_format_not_negative_zero(
        set,
        get_attr(attrs, field),
        field,
        digits
      )
    else
      set
    end
  end

  defp validate_format_not_negative_zero(set, value, field, digits)
       when is_binary(value) do
    value
    |> String.trim()
    |> not_negative_zero?(digits)
    |> if do
      set
    else
      Changeset.add_error(
        set,
        field,
        "negative zero not allowed",
        [validation: :format_not_negative_zero]
      )
    end
  end

  # Expects a trimmed `value`.
  @spec not_negative_zero?(String.t(), non_neg_integer()) :: boolean()
  defp not_negative_zero?(value, digits) do
    !String.match?(value, Regex.compile!("^-0+(?:\\.0{1,#{digits}})?$"))
  end
end
