defmodule CloudDbUi.Orders.Order.Query do
  alias CloudDbUi.Accounts.User
  alias Ecto.Query

  import CloudDbUi.Query
  import Ecto.Query

  @spec fragment_paid() :: Macro.t()
  defmacrop fragment_paid() do
    quote do
      fragment("CASE WHEN ? IS NULL THEN false ELSE true END", o.paid_at)
    end
  end

  @doc """
  Names the concept of a base query. The constructor for this module.
  """
  @spec base() :: %Query{}
  def base() do
    CloudDbUi.Orders.Order
    |> from([as: :order])
    |> select_merge([order: o], %{paid: fragment_paid()})
  end

  @doc """
  Belonging to a specific user. No preloads.
  """
  @spec for_user(%Query{}, %User{}) :: %Query{}
  def for_user(query \\ base(), %User{} = user) do
    where(query, [order: o], o.user_id == ^user.id)
  end

  @doc """
  Preloads `:suborders`. Each sub-order has a preloaded `:product`.

  If a `%User{}` is passed, returns orders owned by the user.
  """
  @spec with_preloaded_suborders_with_products() :: %Query{}
  def with_preloaded_suborders_with_products() do
    base()
    |> with_preloaded_suborders_with_products()
  end

  @spec with_preloaded_suborders_with_products(%User{}) :: %Query{}
  def with_preloaded_suborders_with_products(%User{} = user) do
    base()
    |> for_user(user)
    |> with_preloaded_suborders_with_products()
  end

  @spec with_preloaded_suborders_with_products(%Query{}) :: %Query{}
  def with_preloaded_suborders_with_products(%Query{} = query) do
    query
    |> join_suborders()
    |> join_one(:suborder, :product)
    |> preload([suborder: s, product: p], [suborders: {s, [product: p]}])
    |> group_by([order: o, suborder: s, product: p], [o.id, s.id, p.id])
  end

  @doc """
  Returns orders owned by the `user`.
  Preloads `:suborders`. Each sub-order has a preloaded `:product`.
  Fills the `:total` virtual field.
  """
  @spec with_total_and_preloaded_suborders_with_products(%Query{}, %User{}) ::
          %Query{}
  def with_total_and_preloaded_suborders_with_products(
        %Query{} = query \\ base(),
        %User{} = user
      ) do
    query
    |> for_user(user)
    |> with_preloaded_suborders_with_products()
    |> with_sortable_and_filterable_total()
  end

  @doc """
  Unpaid orders belonging to a specific user. Preloads `:suborders`.
  Fills the `:total` virtual field.
  """
  @spec unpaid_with_preloaded_suborders_with_products(%User{}) :: %Query{}
  def unpaid_with_preloaded_suborders_with_products(%User{} = user) do
    base()
    |> for_user(user)
    |> with_preloaded_suborders_with_products()
    |> where([order: o], is_nil(o.paid_at))
    |> select_merge([suborder: s], %{total: sum(s.unit_price * s.quantity)})
  end

  @doc """
  Preloads `:suborders` and `:user`. Each sub-order has a preloaded
  `:product`. Fills the `:total` virtual field.
  """
  @spec with_full_preloads() :: %Query{}
  def with_full_preloads() do
    base()
    |> with_preloaded_user()
    |> with_preloaded_suborders_with_products()
    |> with_sortable_and_filterable_total()
    |> group_by([user: u], [u.id])
  end

  @doc """
  Preloads `:user`.
  """
  @spec with_preloaded_user(%Query{}) :: %Query{}
  def with_preloaded_user(%Query{} = query \\ base()) do
    query
    |> join_one(:order, :user)
    |> preload([user: u], [user: u])
  end

  @spec fragment_suborder_ids() :: Macro.t()
  defmacrop fragment_suborder_ids() do
    quote do
      fragment(
        "CASE WHEN ? THEN ARRAY[]::bigint[] ELSE ARRAY_AGG(?) END",
        count(s.id) == 0,
        s.id
      )
    end
  end

  @doc """
  Replaces `:suborders` with a list of sub-order IDs.
  """
  @spec with_suborder_ids(%Query{}) :: %Query{}
  def with_suborder_ids(%Query{} = query \\ base()) do
    query
    |> join_suborders()
    |> group_by([order: o], [o.id])
    |> select_merge([suborder: s], %{suborders: fragment_suborder_ids()})
  end

  # @spec fragment_total() :: Macro.t()
  # defmacrop fragment_total() do
  #   quote do
  #     fragment(
  #       "ROUND(SUM(ROUND(?::decimal, 2)), 2)",
  #       coalesce(s.unit_price * s.quantity, 0.0)
  #     )
  #   end
  # end

  # Allows Flop to filter by `:total_filterable` and to sort
  # by `:total_sortable`. Fills the `:total` virtual field.
  @spec with_sortable_and_filterable_total(%Query{}) :: %Query{}
  defp with_sortable_and_filterable_total(%Query{} = query) do
    query
    |> join(
      :inner_lateral,
      [order: o],
      f in subquery(query_total_filterable()),
      [on: true, as: :total_filterable]
    )
    |> select_merge(
      [total_filterable: t],
      %{total: selected_as(t.sum, :total_sortable)}
    )
    |> group_by([total_filterable: t], [t.sum])
  end

  # Return a query to be used in `subquery()`.
  @spec query_total_filterable() :: %Query{}
  defp query_total_filterable() do
    CloudDbUi.Orders.SubOrder
    |> where([so], parent_as(:order).id == so.order_id)
    |> select([so], %{sum: sum(so.unit_price * so.quantity)})
  end

  # `join()` only if `:suborder` has not been used as a named binding yet.
  @spec join_suborders(%Query{}) :: %Query{}
  defp join_suborders(%Query{} = query) do
    join_suborders(query, joined?(query, :suborder))
  end

  @spec join_suborders(%Query{}, boolean()) :: %Query{}
  defp join_suborders(%Query{} = query, true), do: query

  defp join_suborders(%Query{} = query, false) do
    join_many(query, :order, :suborders, :suborder)
  end
end
