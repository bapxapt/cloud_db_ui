defmodule CloudDbUi.Orders.Order.Query do
  import Ecto.Query

  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Accounts.User

  defmacrop fragment_paid() do
    quote do
      fragment("CASE WHEN ? IS NULL THEN false ELSE true END", o.paid_at)
    end
  end

  @doc """
  Names the concept of a base query. The constructor
  for the `Order.Query` module.
  """
  @spec base() :: %Ecto.Query{}
  def base() do
    Order
    |> from([as: :order])
    |> select_merge([order: o], %{paid: fragment_paid()})
  end

  @doc """
  Belonging to a specific user. No preloads.
  """
  @spec for_user(%Ecto.Query{}, %User{}) :: %Ecto.Query{}
  def for_user(query \\ base(), %User{} = user) do
    where(query, [order: o], o.user_id == ^user.id)
  end

  @spec with_preloaded_suborders_with_products() :: %Ecto.Query{}
  def with_preloaded_suborders_with_products() do
    with_preloaded_suborders_with_products(base())
  end

  @doc """
  Preloads `:suborders`. Each sub-order has a preloaded `:product`.

  If a `%User{}` is passed, returns orders owned by the user.
  """
  @spec with_preloaded_suborders_with_products(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_suborders_with_products(%Ecto.Query{} = query) do
    query
    |> with_preloaded_suborders()
    |> with_preloaded_suborder_products()
  end

  @spec with_preloaded_suborders_with_products(%User{}) :: %Ecto.Query{}
  def with_preloaded_suborders_with_products(%User{} = user) do
    base()
    |> for_user(user)
    |> with_preloaded_suborders_with_products()
    |> order_by_paid_at()
  end

  @doc """
  Unpaid orders belonging to a specific user. Preloads `:suborders`.
  """
  @spec unpaid_with_preloaded_suborders_with_products(%User{}) :: %Ecto.Query{}
  def unpaid_with_preloaded_suborders_with_products(%User{} = user) do
    base()
    |> for_user(user)
    |> with_preloaded_suborders_with_products()
    |> where([order: o], is_nil(o.paid_at))
    |> order_by([order: o], [asc: :inserted_at])
  end

  @doc """
  Preloads `:suborders` and `:user`.
  Each sub-order has a preloaded `:product`.
  `%Order{}`s are ordered in descending order by `:paid_at`.
  """
  @spec with_full_preloads() :: %Ecto.Query{}
  def with_full_preloads() do
    base()
    |> with_preloaded_user()
    |> with_preloaded_suborders_with_products()
    |> order_by_paid_at()
  end

  @doc """
  Preloads `:user`.
  """
  @spec with_preloaded_user(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_user(%Ecto.Query{} = query \\ base()) do
    query
    |> join(:left, [order: o], u in User, [on: o.user_id == u.id, as: :user])
    |> preload([user: u], [user: u])
  end

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
  @spec with_suborder_ids(%Ecto.Query{}) :: %Ecto.Query{}
  def with_suborder_ids(%Ecto.Query{} = query \\ base()) do
    query
    |> join_suborders()
    |> group_by([order: o], [o.id])
    |> select_merge([suborder: s], %{suborders: fragment_suborder_ids()})
  end

  # defmacrop fragment_total() do
  #   quote do
  #     fragment(
  #       "ROUND(SUM(ROUND(?::decimal, 2)), 2)",
  #       coalesce(s.unit_price * s.quantity, 0.0)
  #     )
  #   end
  # end

  # @spec with_filled_total(%Ecto.Query{}) :: %Ecto.Query{}
  # defp with_filled_total(%Ecto.Query{} = query) do
  #   query
  #   |> join_suborders()
  #   |> group_by([order: o], [o.id])
  #   |> select_merge([order: o, suborder: s], %{total: fragment_total()})
  # end

  # Preloads `:suborders`.
  @spec with_preloaded_suborders(%Ecto.Query{}) :: %Ecto.Query{}
  defp with_preloaded_suborders(%Ecto.Query{} = query) do
    query
    |> join_suborders()
    |> preload([suborder: s], [suborders: s])
  end

  @spec with_preloaded_suborder_products(%Ecto.Query{}) :: %Ecto.Query{}
  defp with_preloaded_suborder_products(%Ecto.Query{} = query) do
    query
    |> join(
      :left,
      [suborder: s],
      p in Product,
      [on: p.id == s.product_id, as: :product]
    )
    |> preload([suborder: s, product: p], [suborders: {s, [product: p]}])
  end

  @spec join_suborders(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_suborders(%Ecto.Query{} = query) do
    join(
      query,
      :left,
      [order: o],
      s in SubOrder,
      [on: o.id == s.order_id, as: :suborder]
    )
  end

  @spec order_by_paid_at(%Ecto.Query{}) :: %Ecto.Query{}
  defp order_by_paid_at(%Ecto.Query{} = query) do
    order_by(query, [order: o], [desc_nulls_first: :paid_at])
  end
end
