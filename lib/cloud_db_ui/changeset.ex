defmodule CloudDbUi.Changeset do
  alias Ecto.Changeset
  alias Phoenix.HTML.Form

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
  Add a "can't be blank" error if the input field is blank, ignoring
  the presence of a default value in the schema.
  """
  @spec validate_required_with_default(%Changeset{}, [atom()]) :: %Changeset{}
  def validate_required_with_default(%Changeset{} = set, fields) do
    Enum.reduce(fields, set, fn field, acc ->
      if CloudDbUiWeb.Utilities.trim(set.params["#{field}"]) in ["", nil] do
        add_error(acc, field, {"can't be blank", [validation: :required]})
      else
        set
      end
    end)
  end

  @doc """
  Put a "did not change" error (an other `:message` can be passed
  in `opts`) for a `field`, if both conditions are true:

    - there is no change for the `field` in change`set.changes`;
    - there are no errors for the `field` in change`set.errors`.
  """
  @spec validate_no_change(%Changeset{}, atom(), keyword()) :: %Changeset{}
  def validate_no_change(%Changeset{} = set, field, opts \\ []) do
    cond do
      Map.has_key?(set.changes, field) ->
        set

      Keyword.has_key?(set.errors, field) ->
        set

      true ->
        Changeset.add_error(set, :email, opts[:message] || "did not change")
    end
  end

  # TODO: combine with maybe_validate_format_not_negative_zero() (pass fn_validate_decimal)

  @doc """
  Validate decimal format, if there is no error corresponding
  to the passed `field`, and the string-converted `field` exists
  in `changeset.params`.
  """
  @spec maybe_validate_format_decimal(
          %Changeset{},
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  def maybe_validate_format_decimal(changeset, field, digits \\ 2) do
    cond do
      Keyword.has_key?(changeset.errors, field) -> changeset
      !Map.has_key?(changeset.params, "#{field}") -> changeset
      !is_binary(changeset.params["#{field}"]) -> changeset
      String.trim(changeset.params["#{field}"]) == "" -> changeset
      true -> validate_format_decimal(changeset, field, digits)
    end
  end

  @doc """
  Validate the absence of a negative zero, if there is no error
  corresponding to the passed `field`, and the string-converted
  `field` exists in `changeset.params`.
  """
  @spec maybe_validate_format_not_negative_zero(
          %Changeset{},
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  def maybe_validate_format_not_negative_zero(changeset, field, digits \\ 2) do
    cond do
      Keyword.has_key?(changeset.errors, field) -> changeset
      !Map.has_key?(changeset.params, "#{field}") -> changeset
      !is_binary(changeset.params["#{field}"]) -> changeset
      String.trim(changeset.params["#{field}"]) == "" -> changeset
      true -> validate_format_not_negative_zero(changeset, field, digits)
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
  Return a unique constraint (`validation: :unsafe_unique`) error.
  """
  @spec unique_constraint_error(atom(), String.t()) :: error()
  def unique_constraint_error(field, message \\ "has already been taken") do
    {message, [validation: :unsafe_unique, fields: [field]]}
  end

  @doc """
  `validate_confirmation()` of a `field` if there is a change
  corresponding to the `field` in `changeset.changes`.

  ## Options

    * `:target` - the value of `"_target"` from params. If non-`nil`,
      enables non-strict confirmation validation. This means that
      while the `"\#{field}_confirmation"` input field is focused,
      there will be no error as long as the value of the `field`
      begins with the value of `"\#{field}_confirmation"`.
      Defaults to `nil`.
  """
  @spec maybe_validate_confirmation(%Changeset{}, atom(), keyword()) ::
          %Changeset{}
  def maybe_validate_confirmation(changeset, field, opts \\ []) do
    if Map.has_key?(changeset.changes, field) do
      maybe_validate_confirmation(
        changeset,
        field,
        opts,
        !target?(opts[:target], "#{field}_confirmation")
      )
    else
      changeset
    end
  end

  @doc """
  Transform `fields` before attempting to `cast()`. Transforming
  the values of `fields` with `&CloudDbUiWeb.Utilities.trim/1`
  allows to avoid an `"is invalid"` error when an extra trimmable space
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

  # Restore the initial value of `fields` if they are contained
  # in `attrs`. Useful for restoring the value of attributes cast
  # with `cast_transformed()`.
  @spec put_changes_from_attrs(%Changeset{}, attrs(), [atom()]) :: %Changeset{}
  def put_changes_from_attrs(changeset, attrs, fields) do
    Enum.reduce(fields, changeset, &put_change_from_attrs(&2, attrs, &1))
  end

  # Put `nil` under the `key` into change`set.changes` if any condition
  # is true:
  #
  #   - change`set.changes[key]` is an empty string (`""`);
  #   - there is no change of `key` in change`set.changes`, and the trimmed
  #     non-nil `object[key]` is an empty string (`""`).
  @spec maybe_nilify_change(%Changeset{}, struct(), atom()) :: %Changeset{}
  def maybe_nilify_change(%Changeset{} = set, object, key) do
    value = Map.get(object, key)

    cond do
      Map.get(set.changes, key) == "" -> Changeset.put_change(set, key, nil)
      Map.has_key?(set.changes, key) -> set
      is_nil(value) -> set
      String.trim(value) != "" -> set
      true -> Changeset.put_change(set, key, nil)
    end
  end

  @doc """
  Ensure `%DateTime{}`s in the future are not allowed.
  """
  @spec validator_not_in_the_future(atom(), %DateTime{}) :: errors()
  def validator_not_in_the_future(field, %DateTime{} = value) do
    DateTime.utc_now()
    |> DateTime.compare(value)
    |> case do
      :lt -> [{field, {"can't be in the future", [validation: :not_future]}}]
      _gt_or_eq -> []
    end
  end

  @doc """
  Ensure `%DateTime{}`s before the Unix start time are not allowed.
  """
  @spec validator_not_in_the_far_past(atom(), %DateTime{}) :: errors()
  def validator_not_in_the_far_past(field, %DateTime{} = value) do
    DateTime.from_unix!(0)
    |> DateTime.compare(value)
    |> case do
      :gt ->
        [{field, {"too far in the past", [validation: :not_far_past]}}]

      _lt_or_eq ->
        []
    end
  end

  @doc """
  Get a value corresponding to the `key` from `attrs`, where a key
  can be a string or an atom.
  """
  @spec get_attr(attrs(), atom()) :: any()
  def get_attr(%{} = attrs, key) do
    case Map.has_key?(%{} = attrs, key) do
      true -> attrs[key]
      false -> attrs["#{key}"]
    end
  end

  @doc """
  Check existence of the `key` in `attrs`, where a key can be a string
  or an atom.
  """
  @spec has_attr?(attrs(), atom()) :: boolean()
  def has_attr?(%{} = attrs, key) do
    Map.has_key?(attrs, key) or Map.has_key?(attrs, "#{key}")
  end

  @doc """
  Get errors corresponding to `fields` as a map of error lists.
  """
  @spec get_errors(%Changeset{} | %Form{}, [atom()]) :: %{atom() => [error()]}
  def get_errors(changeset_or_form, fields) do
    fields
    |> Enum.filter(&Keyword.has_key?(changeset_or_form.errors, &1))
    |> Map.new(fn field ->
      {field, Keyword.get_values(changeset_or_form.errors, field)}
    end)
  end

  @doc """
  Check whether any error (with an optional `validation`)
  exists for a `field`.

  Also can accept a list of `validations` and an `operator`.
  If the `operator` is `:include`, any errors with `:validation`
  in `validations` count. If the `op`erator is `:exclude`, any
  errors with `:validation` not in `validations` (or without
  `:validation` at all) count.
  """
  @spec has_error?(%Changeset{} | %Form{}, atom()) :: boolean()
  def has_error?(set_or_form, field) do
    Keyword.get_values(set_or_form.errors, field) != []
  end

  @spec has_error?(%Changeset{} | %Form{}, atom(), atom()) :: boolean()
  def has_error?(set_or_form, field, validation) do
    set_or_form.errors
    |> Keyword.get_values(field)
    |> Enum.any?(fn {_message, extra_info} = _error ->
      extra_info[:validation] == validation
    end)
  end

  @spec has_error?(%Changeset{} | %Form{}, atom(), [atom()], atom()) ::
          boolean()
  def has_error?(set_or_form, field, validations, operator) do
    set_or_form.errors
    |> Keyword.get_values(field)
    |> Enum.any?(fn {_message, extra_info} = _error ->
      case operator do
        :include -> extra_info[:validation] in validations
        :exclude -> extra_info[:validation] not in validations
      end
    end)
  end

  @doc """
  Add a unique constraint error for the `field`, if all conditions
  are true:

    - `add?` is `true`;
    - the `changeset` has a change for the `field`;
    - the `changeset` does not have an unique constraint error
      corresponding to the `field`.
  """
  @spec maybe_add_unique_constraint_error(
          %Changeset{},
          atom(),
          boolean(),
          String.t()
        ) :: %Changeset{}
  def maybe_add_unique_constraint_error(
        %Changeset{} = changeset,
        field,
        add?,
        message \\ "has already been taken"
      ) do
    cond do
      !add? -> changeset
      !Map.has_key?(changeset.changes, field) -> changeset
      has_error?(changeset, field, :unsafe_unique) -> changeset
      true -> add_unique_constraint_error(changeset, field, message)
    end
  end

  @doc """
  The message text for a decimal format error
  (when not a `valid_number_format?()`).
  """
  @spec decimal_format_error_message(non_neg_integer()) :: String.t()
  def decimal_format_error_message(digits) do
    Kernel.<>(
      "invalid format; valid examples: 5, 7.9, 12.",
      String.duplicate("9", digits)
    )
  end

  defp maybe_validate_confirmation(set, field, opts, false = _strict?) do
    set.changes
    |> Map.fetch!(field)
    |> String.starts_with?(Map.get(set.params, "#{field}_confirmation", ""))
    |> case do
      true -> set
      false -> Changeset.validate_confirmation(set, field, opts)
    end
  end

  defp maybe_validate_confirmation(changeset, field, opts, true = _strict?) do
    Changeset.validate_confirmation(changeset, field, opts)
  end

  # Add an `error()` (`{String.t(), keyword()}`) to a `changeset`.
  @spec add_error(%Changeset{}, atom(), error()) :: %Changeset{}
  defp add_error(%Changeset{} = changeset, field, {message, extra_info}) do
    Changeset.add_error(changeset, field, message, extra_info)
  end

  # Add a unique constraint violation error without calling
  # `unsafe_validate_unique_constraints()`.
  @spec add_unique_constraint_error(%Changeset{}, atom(), String.t()) ::
          %Changeset{}
  defp add_unique_constraint_error(%Changeset{} = changeset, field, message) do
    add_error(changeset, field, unique_constraint_error(field, message))
  end

  # The `value` is a `%Decimal{}`, get the `:sign` option.
  @spec decimal_sign_validator(atom(), %Decimal{}, keyword()) ::
          [{atom(), error()}]
  defp decimal_sign_validator(field, value, opts) do
    decimal_sign_validator(field, value, opts[:sign], opts[:message])
  end

  @spec decimal_sign_validator(atom(), %Decimal{}, atom(), String.t() | nil) ::
          [{atom(), error()}]
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
    case has_attr?(attrs, field) do
      true -> Changeset.put_change(set, field, get_attr(attrs, field))
      false -> set
    end
  end

  # `validate_format()` for a decimal (`inputmode="decimal"`) field,
  # ensuring valid number format. Gets its value from `changeset.params`.
  # Trimmable spaces do not affect validity.
  @spec validate_format_decimal(
          %Changeset{},
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  defp validate_format_decimal(%Changeset{} = changeset, field, digits) do
    changeset.params["#{field}"]
    |> String.trim()
    |> CloudDbUiWeb.Utilities.valid_number_format?(digits)
    |> if do
      changeset
    else
      add_error(
        changeset,
        field,
        {decimal_format_error_message(digits), [validation: :format_decimal]}
      )
    end
  end

  # `validate_format()` for a decimal (`inputmode="decimal"`) field,
  # ensuring absence of a negative zero in floats and in strings.
  @spec validate_format_not_negative_zero(
          %Changeset{},
          atom(),
          non_neg_integer()
        ) :: %Changeset{}
  defp validate_format_not_negative_zero(%Changeset{} = set, field, digits) do
    set.params["#{field}"]
    |> negative_zero?(digits)
    |> case do
      true -> add_error(set, field, negative_zero_error())
      false -> set
    end
  end

  @spec negative_zero?(String.t(), non_neg_integer()) :: boolean()
  defp negative_zero?(value, digits) when is_binary(value) do
    String.match?(value, Regex.compile!("^\\s*-0+(?:\\.0{1,#{digits}})?\\s*$"))
  end

  @spec negative_zero_error(String.t()) :: error()
  defp negative_zero_error(msg \\ "negative zero is not allowed") do
    {msg, [validation: :format_not_negative_zero]}
  end

  # Check whether the passed `field` is the field that triggered
  # the sending of an event.
  @spec target?([String.t()] | nil, String.t()) :: boolean()
  defp target?(nil, _field), do: false

  defp target?(target, field), do: List.last(target) == field
end
