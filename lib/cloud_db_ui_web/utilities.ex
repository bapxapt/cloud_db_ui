defmodule CloudDbUiWeb.Utilities do
  alias Phoenix.LiveView.Socket

  @type error() :: CloudDbUi.Type.error()

  @doc """
  If a string is passed, trim it. Otherwise, return with no changes.
  """
  @spec trim(any()) :: any()
  def trim(trimmable) when is_binary(trimmable), do: String.trim(trimmable)

  def trim(non_trimmable), do: non_trimmable

  @doc """
  `to_string()`, then `String.trim()` and `String.downcase()`.
  """
  @spec trim_downcase(any()) :: String.t()
  def trim_downcase(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  @doc """
  Determine whether describing the number would require
  a plural form: 2 apples, -1 hour.
  Generally, anything that's not one or minus one in number
  needs a plural form.
  """
  @spec needs_plural_form?(number()) :: boolean()
  def needs_plural_form?(count) when is_number(count) do
    count != 1 and count != -1
  end

  @doc """
  Round to `precision` and convert to a string. Remove unnecessary ".0"
  at the end.
  """
  @spec round_into_string(float(), integer()) :: binary()
  def round_into_string(roundable, precision \\ 2) do
    roundable
    |> :erlang.float_to_binary([{:decimals, precision}, :compact])
    |> String.replace(~r/\.0+$/, "")
  end

  @doc """
  Check if a string is a valid representation of an integer
  or a non-scientific decimal number. Valid strings are:

    - a representation of an integer with no dot after;
    - a representation of a decimal with both integer and fractional parts
      separated by a dot (up to `digits` decimal places after the dot).

  Expects a trimmed `value`.
  """
  @spec valid_number_format?(String.t(), non_neg_integer()) :: boolean()
  def valid_number_format?(value, 0), do: Regex.match?(~r/^-?\d+$/, value)

  def valid_number_format?(value, digits) when digits > 0 do
    "^-?\\d+(?:\\.\\d{1,#{digits}})?$"
    |> Regex.compile!()
    |> Regex.match?(value)
  end

  @doc """
  Convert a value of a form field to a string with `digits`
  after the point. Preserves trimmable whitespaces.
  """
  @spec format(%Decimal{} | String.t()) :: String.t()
  def format(value), do: format(value, 2)

  def format(value, digits) when is_binary(value) do
    trimmed = String.trim(value)

    if valid_number_format?(trimmed, digits) do
      formatted =
        trimmed
        |> Decimal.new()
        |> format(digits)

      String.replace(value, ~r/-?\d+(?:\.\d+)?(?=\s*?$)/, formatted)
    else
      value
    end
  end

  @spec format(%Decimal{} | String.t(), integer()) :: String.t()
  def format(%Decimal{} = value, digits) do
    value
    |> Decimal.round(digits)
    |> Decimal.to_string(:normal)
  end

  @doc """
  If no corresponding error in `form.errors`, `format()` a field.
  This `format()` call has default values of parameters.
  If there is an error, return the unchanged value of the field.
  """
  @spec maybe_format(%Phoenix.HTML.Form{}, atom()) :: String.t() | %Decimal{}
  def maybe_format(%Phoenix.HTML.Form{} = form, field_key) do
    maybe_format(
      form[field_key].value,
      !Keyword.has_key?(form.errors, field_key),
      "",
      form[field_key].value
    )
  end

  # TODO: rewrite as run_if() and pass &format(&1, "0.00", 2) (or &format/1)?

  @doc """
  `format()` with default values of parameters and with a condition.
  If the condition fails, return a `default` value
  (this is not a `default` parameter passed to `format()` itself).
  """
  @spec maybe_format(String.t() | %Decimal{} | nil, boolean(), String.t()) ::
          any()
  def maybe_format(value, format?, prefix \\ "") do
    maybe_format(value, format?, prefix, "N/A")
  end

  @spec maybe_format(
          String.t() | %Decimal{} | nil,
          boolean(),
          String.t(),
          any()
        ) :: any()
  def maybe_format(value, true, prefix, _default), do: prefix <> format(value)

  def maybe_format(_value, false = _format?, _prefix, default), do: default

  @doc """
  If not `nil`, convert a `%DateTime{}` to string.
  """
  @spec format_date_time(nil) :: String.t()
  def format_date_time(nil), do: ""

  @spec format_date_time(%DateTime{}) :: String.t()
  def format_date_time(dt) do
    dt
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
    |> String.replace_suffix("Z", "")
  end

  @doc """
  If the type is `float()`, round a value to `digits` after the point.
  """
  @spec round(float(), 0..15) :: float()
  def round(value, digits) when is_float(value) do
    Float.round(value, digits)
  end

  @spec round(integer(), any()) :: integer()
  def round(value, _digits) when is_integer(value), do: value

  @doc """
  Convert a string representing a Boolean value (`"true"` or `"false"`)
  into a corresponding value.
  """
  @spec to_boolean(String.t() | boolean()) :: boolean()
  def to_boolean("false"), do: false

  def to_boolean("true"), do: true

  def to_boolean(value) when is_boolean(value), do: value

  @doc """
  Check whether a string represents an integer. Expects a trimmed `id`.
  """
  @spec valid_id?(String.t()) :: boolean()
  def valid_id?(id), do: String.match?(id, ~r/^-?\d+$/)

  @doc """
  Sort structures within a list by the passed `key`.
  """
  @spec sort_structures([struct()], atom()) :: [struct()]
  def sort_structures(structs, key), do: sort_structures(structs, key, true)

  @spec sort_structures([struct()], atom(), boolean()) :: [struct()]
  def sort_structures(structs, key, true = _ascending) do
    Enum.sort(structs, &(Map.fetch!(&1, key) <= Map.fetch!(&2, key)))
  end

  def sort_structures(structs, key, false = _ascending) do
    Enum.sort(structs, &(Map.fetch!(&1, key) >= Map.fetch!(&2, key)))
  end

  @doc """
  Check whether two string values (of an input field) differ
  significantly. An addition of a trimmable whitespace (at the beginning
  of at the end) or a change of a letter case are not considered
  to be significant changes.
  """
  @spec significant_change?(String.t(), String.t()) :: boolean()
  def significant_change?(value, prev) do
    trim_downcase(value) != trim_downcase(prev)
  end

  @doc """
  Create a `:form` out of a passed `changeset` and assign to a passed
  `%Socket{}`.
  """
  @spec assign_form(%Socket{}, %Ecto.Changeset{}, keyword()) :: %Socket{}
  def assign_form(socket, %Ecto.Changeset{} = changeset, opts \\ []) do
    Phoenix.Component.assign(
      socket,
      :form,
      Phoenix.Component.to_form(changeset, opts)
    )
  end

  @doc """
  Delete a `key` from `socket.assigns`.
  """
  @spec delete(%Socket{}, atom()) :: %Socket{}
  def delete(%Socket{} = socket, key) do
    Map.update!(socket, :assigns, &Map.delete(&1, key))
  end

  @doc """
  Turn a list of `values` into a comma-separated string.
  """
  @spec comma_separated_values([any()]) :: String.t()
  def comma_separated_values(values) do
    values
    |> Enum.map(&"#{&1}")
    |> Enum.join(", ")
  end

  @doc """
  Get the text of `@doc` (for a `:function`) or of `@typedoc`
  (for a `:type`).
  """
  @spec get_doc(module(), atom(), atom(), non_neg_integer()) ::
          String.t() | nil
  def get_doc(module, kind \\ :function, name, arity) do
    module
    |> Code.fetch_docs()
    |> case do
      {:error, _} ->
        nil

      {:docs_v1, _, _, _, _, _, docs} ->
        docs
        |> Enum.find(fn {{knd, nm, art}, _, _, _, _,} ->
          {knd, nm, art} == {kind, name, arity}
        end)
        |> case do
          {{^kind, ^name, ^arity}, _, _, %{"en" => doc}, _} -> doc
          _any -> nil
        end
    end
  end
end