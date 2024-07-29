defmodule CloudDbUi.FlopFilters do
  @moduledoc """
  A module containing custom filters
  for [Flop Phoenix](https://hexdocs.pm/flop_phoenix).
  """

  alias Ecto.Query
  alias Ecto.Query.DynamicExpr
  alias Flop.Filter

  import CloudDbUiWeb.Utilities
  import Ecto.Query

  @type error() :: CloudDbUi.Type.error()
  @type params() :: CloudDbUi.Type.params()

  @doc """
  Trim the string `value` of a filter input field and convert it
  to a `%Decimal{}` before using it in a query.
  """
  @spec to_decimal!(%Query{}, %Filter{}, keyword()) :: %Query{}
  def to_decimal!(query, %Filter{op: op, value: value}, opts) do
    val_new =
      value
      |> String.trim()
      |> parse_decimal()
      |> case do
        {%Decimal{sign: 1} = parsed, ""} -> parsed
        _error_negative_or_not_fully_parsed -> Decimal.new("0.00")
      end

    if Keyword.has_key?(opts, :field) do
      d =
        dynamic(
          [{^Keyword.fetch!(opts, :source), dynamic_binding}],
          field(dynamic_binding, ^opts[:field])
        )

      where(query, ^dynamic_condition(d, op, val_new))
    else
      where(query, ^dynamic_condition(dynamic_with_source(opts), op, val_new))
    end
  end

  @doc """
  Trim the `value` of a filter input field before using it in a query.
  Any spaces between words get replaced with a single whitespace.
  """
  @spec trim!(%Query{}, %Filter{}, keyword()) :: %Query{}
  def trim!(%Query{} = query, %Filter{op: op, value: value}, opts) do
    where(
      query,
      ^dynamic_condition(dynamic_with_source(opts), op, trim_words(value))
    )
  end

  @doc """
  Check whether the count of associated objects accessible by the foreign
  key is not equal to zero. An existing named binding should be passed
  as the `:source` (for example, `%User{}` queries have the `:order`
  binding).
  If `opts` contain `:non_nil_field`, retrieved associated objects
  in which the value of this is field equal to `nil` would be filtered out
  before the counting.
  """
  @spec has_associated_objects?(%Query{}, %Filter{}, keyword()) :: %Query{}
  def has_associated_objects?(query, %Filter{op: op, value: value}, opts) do
    case Keyword.get(opts, :non_nil_field) do
      nil ->
        dynamic(
          [{^Keyword.fetch!(opts, :source), dynamic_binding}],
          count(dynamic_binding)
        )

      field ->
        dynamic(
          [{^Keyword.fetch!(opts, :source), dyn_binding}],
          filter(count(dyn_binding), not is_nil(field(dyn_binding, ^field)))
        )
    end
    |> zero?(query, op, value)
  end

  @doc """
  Filter associated objects accessible by the foreign key by the `value`
  of their `field`. An existing named binding should be passed
  as the `:source` (for example, `%User{}` queries have the `:order`
  binding). The `value` gets trimmed before being used in the `query`,
  and all spaces between words in it get replaced with a single whitespace.
  """
  @spec with_associated_object_field!(%Query{}, %Filter{}, keyword()) ::
          %Query{}
  def with_associated_object_field!(query, %{op: op, value: value}, opts) do
    expr =
      dynamic(
        [{^Keyword.fetch!(opts, :source), dyn_binding}],
        field(dyn_binding, ^Keyword.fetch!(opts, :field))
      )

    having(query, ^dynamic_condition(expr, op, trim_words(value)))
  end

  @doc """
  `custom_field_opts()` for a `type="text"` (not `inputmode="decimal"`)
  input field that deals with own fields of an object (e.g. `user.email`).
  """
  @spec custom_text_field_opts(atom()) :: keyword()
  def custom_text_field_opts(source) do
    custom_field_opts(:trim!, source, :string, [:ilike])
  end

  @doc """
  `custom_field_opts()` for a `type="text" inputmode="decimal"`
  input field.
  """
  @spec custom_decimal_field_opts(atom() | keyword()) :: keyword()
  def custom_decimal_field_opts(source) do
    custom_field_opts(:to_decimal!, source, :string, [:>=, :<=])
  end

  @doc """
  `custom_field_opts()` for a "Has Xs" `<select>` input field.
  """
  @spec custom_has_objects_field_opts(atom(), atom() | nil) :: keyword()
  def custom_has_objects_field_opts(binding, field \\ nil) do
    custom_field_opts(
      :has_associated_objects?,
      (if field, do: [source: binding, non_nil_field: field], else: binding),
      :boolean,
      [:!=]
    )
  end

  @doc """
  `custom_field_opts()` for a `type="text"` (not `inputmode="decimal"`)
  input field that deals with a field of an associated object
  (e.g. `order.user.email`).
  """
  @spec custom_associated_object_field_opts(atom(), atom()) :: keyword()
  def custom_associated_object_field_opts(named_binding, field) do
    custom_field_opts(
      :with_associated_object_field!,
      [source: named_binding, field: field],
      :string,
      [:ilike]
    )
  end

  @doc """
  A `Keyword` list of options for a single custom filter field
  in `:custom_fields` within `:adapter_opts` of a `@derive` `Flop.Schema`.
  If `opts` is not a list, it is considered to be the value for `:source`.
  """
  @spec custom_field_opts(atom(), keyword() | atom(), atom(), [atom()]) ::
          keyword()
  def custom_field_opts(name, source, type, ops) when is_atom(source) do
    custom_field_opts(name, [source: source], type, ops)
  end

  def custom_field_opts(name, opts, type, ops) do
    [filter: {__MODULE__, name, opts}, ecto_type: type, operators: ops]
  end

  @doc """
  A `Keyword` list of options for a single join field in `:custom_fields`
  within `:adapter_opts` of a `@derive` `Flop.Schema`.
  """
  def join_field_opts(binding, field, ecto_type) do
    [binding: binding, field: field, ecto_type: ecto_type]
  end

  @spec zero?(%DynamicExpr{}, %Query{}, atom(), any()) :: %Query{}
  defp zero?(expr, query, op, value) do
    having(query, ^dynamic_condition(dynamic(^expr == 0), op, value))
  end

  @spec dynamic_condition(%DynamicExpr{}, atom(), any()) :: %DynamicExpr{}
  defp dynamic_condition(expr, op, value) do
    case op do
      :== -> dynamic([dynamic_binding], ^expr == ^value)
      :!= -> dynamic([dynamic_binding], ^expr != ^value)
      :=~ -> dynamic([dynamic_binding], ilike(^expr, ^"%#{value}%"))
      :empty -> dynamic([dynamic_binding], is_nil(^expr) == true)
      :not_empty -> dynamic([dynamic_binding], is_nil(^expr) == false)
      :<= -> dynamic([dynamic_binding], ^expr <= ^value)
      :< -> dynamic([dynamic_binding], ^expr < ^value)
      :>= -> dynamic([dynamic_binding], ^expr >= ^value)
      :> -> dynamic([dynamic_binding], ^expr > ^value)
      :in -> dynamic([dynamic_binding], ^expr in ^value)
      :not_in -> dynamic([dynamic_binding], ^expr not in ^value)
      :contains -> dynamic([dynamic_binding], ^value in any(expr))
      :not_contains -> dynamic([dynamic_binding], ^value not in any(expr))
      :like -> dynamic([dynamic_binding], like(^expr, ^"%#{value}%"))
      :not_like -> dynamic([dynamic_binding], not like(^expr, ^"%#{value}%"))
      :ilike -> dynamic([dynamic_binding], ilike(^expr, ^"%#{value}%"))
      :not_ilike -> dynamic([dynamic_binding], not ilike(^expr, ^"%#{value}%"))
    end
  end

  @spec dynamic_with_source(keyword()) :: %Ecto.Query.DynamicExpr{}
  defp dynamic_with_source(opts) do
    dynamic([dyn_binding], field(dyn_binding, ^Keyword.fetch!(opts, :source)))
  end
end
