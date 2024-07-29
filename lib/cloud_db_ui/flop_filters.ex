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
    value_new =
      value
      |> String.trim()
      |> parse_decimal()
      |> case do
        {%Decimal{sign: 1} = parsed, ""} -> parsed
        _error_negative_or_not_fully_parsed -> Decimal.new("0.00")
      end

    expr = dynamic([r], field(r, ^Keyword.fetch!(opts, :source)))

    where(query, ^dynamic_condition(expr, op, value_new))
  end

  @doc """
  Trim the `value` of a filter input field before using it in a query.
  """
  @spec trim!(%Query{}, %Filter{}, keyword()) :: %Query{}
  def trim!(query, %Filter{op: op, value: value}, opts) do
    value_new =
      case op in [:like, :not_like, :ilike, :not_ilike] do
        true -> "%" <> String.trim(value) <> "%"
        false -> String.trim(value)
      end

    expr = dynamic([r], field(r, ^Keyword.fetch!(opts, :source)))

    where(query, ^dynamic_condition(expr, op, value_new))
  end

  @doc """
  Check whether the order count (including unpaid orders) is equal to zero.
  """
  @spec has_orders?(%Query{}, %Filter{}, keyword()) :: %Query{}
  def has_orders?(query, %Filter{op: op, value: value}, opts) do
    [{^Keyword.fetch!(opts, :source), dynamic_binding}]
    |> dynamic(count(dynamic_binding))
    |> non_zero?(query, op, value)
  end

  @doc """
  Check whether the paid order count is equal to zero.
  """
  @spec has_paid_orders?(%Query{}, %Filter{}, keyword()) :: %Query{}
  def has_paid_orders?(query, %Filter{op: op, value: value}, opts) do
    [{^Keyword.fetch!(opts, :source), dynam_binding}]
    |> dynamic(filter(count(dynam_binding), not is_nil(dynam_binding.paid_at)))
    |> non_zero?(query, op, value)
  end

  @doc """
  A `Keyword` list of options for a custom filter field in `:custom_fields`
  within `:adapter_opts` of a `@derive` `Flop.Schema`.
  If `opts` is an atom, it is considered to be the value for `:source`.
  """
  @spec custom_field_opts(
          atom(),
          keyword() | atom(),
          atom() | nil,
          [atom()] | nil
        ) :: keyword()
  def custom_field_opts(name, opts \\ [], type \\ nil, ops \\ nil) do
    [ecto_type: type, operators: ops]
    |> Enum.reduce([filter: custom_filter_opts(name, opts)], fn {k, v}, acc ->
      case v do
        nil -> acc
        non_nil -> Keyword.put_new(acc, k, non_nil)
      end
    end)
  end

  # The value for a custom `:filter` field in `:custom_fields`
  # within `:adapter_opts` of a `@derive` `Flop.Schema`.
  @spec custom_filter_opts(atom(), keyword()) :: {module(), atom(), keyword()}
  defp custom_filter_opts(name, opts) when is_list(opts) do
    {__MODULE__, name, opts}
  end

  @spec custom_filter_opts(atom(), atom()) :: {module(), atom(), keyword()}
  defp custom_filter_opts(name, src), do: {__MODULE__, name, [source: src]}

  @spec non_zero?(%DynamicExpr{}, %Query{}, atom(), any()) :: %Query{}
  defp non_zero?(expr, query, op, value) do
    having(query, ^dynamic_condition(dynamic(^expr == 0), op, value))
  end

  @spec dynamic_condition(%DynamicExpr{}, atom(), any()) :: %DynamicExpr{}
  defp dynamic_condition(expr, op, value) do
    case op do
      :== -> dynamic([r], ^expr == ^value)
      :!= -> dynamic([r], ^expr != ^value)
      :=~ -> dynamic([r], ilike(^expr, ^value))
      :empty -> dynamic([r], is_nil(^expr) == true)
      :not_empty -> dynamic([r], is_nil(^expr) == false)
      :<= -> dynamic([r], ^expr <= ^value)
      :< -> dynamic([r], ^expr < ^value)
      :>= -> dynamic([r], ^expr >= ^value)
      :> -> dynamic([r], ^expr > ^value)
      :in -> dynamic([r], ^expr in ^value)
      :not_in -> dynamic([r], ^expr not in ^value)
      :contains -> dynamic([r], ^value in any(expr))
      :not_contains -> dynamic([r], ^value not in any(expr))
      :like -> dynamic([r], like(^expr, ^value))
      :not_like -> dynamic([r], not like(^expr, ^value))
      :ilike -> dynamic([r], ilike(^expr, ^value))
      :not_ilike -> dynamic([r], not ilike(^expr, ^value))
    end
  end
end
