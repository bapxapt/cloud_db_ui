defmodule CloudDbUi.Orders.SubOrder.Query do
  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders.Order
  alias Ecto.Query

  import CloudDbUi.Query
  import Ecto.Query

  @doc """
  Names the concept of a base query. The constructor for this module.
  Fills the `:subtotal` virtual field.
  """
  @spec base() :: %Query{}
  def base() do
    CloudDbUi.Orders.SubOrder
    |> from([as: :suborder])
    |> select_merge([suborder: s], %{subtotal: s.unit_price * s.quantity})
  end

  @doc """
  With specified IDs (primary key).
  """
  @spec for_ids(%Query{}, [pos_integer()]) :: %Query{}
  def for_ids(%Query{} = query \\ base(), ids) do
    where(query, [suborder: s], s.id in ^ids)
  end

  @doc """
  Belonging to a specific order.
  """
  @spec for_order(%Query{}, %Order{}) :: %Query{}
  def for_order(%Query{} = query \\ base(), %Order{} = order) do
    where(query, [suborder: s], s.order_id == ^order.id)
  end

  @doc """
  Belonging to a specific user. Fills the `paid` virtual field.
  """
  @spec for_user(%Query{}, %User{}) :: %Query{}
  def for_user(%Query{} = query \\ base(), %User{} = user) do
    query
    |> join_orders()
    |> where(
      [suborder: s, order: o],
      s.order_id == o.id and o.user_id == ^user.id
    )
  end

  @doc """
  Preloads `:order`. Fills the `:subtotal` virtual field.
  """
  @spec with_preloaded_order(%Query{}) :: %Query{}
  def with_preloaded_order(%Query{} = query \\ base()) do
    query
    |> join_orders()
    |> preload([order: o], [order: o])
  end

  @doc """
  Preloads `:product` and `:order`. The `:order` has
  a preloaded `:user`. Fills the `:subtotal` virtual field.
  """
  @spec with_preloaded_product_and_order_user(%Query{}) :: %Query{}
  def with_preloaded_product_and_order_user(%Query{} = query \\ base()) do
    query
    |> join_products()
    |> preload([product: p], [product: p])
    |> with_preloaded_order_user()
  end

  @doc """
  Preloads `:order` and `:product`. The `:order` has a preloaded `:user`,
  the `:product` has a preloaded `:product_type`.
  Fills the `:subtotal` virtual field.
  """
  @spec with_full_preloads() :: %Query{}
  def with_full_preloads() do
    base()
    |> with_preloaded_order_user()
    |> join_products()
    |> join_one(:product, :product_type)
    |> preload(
      [product: p, product_type: t],
      [product: {p, [product_type: t]}]
    )
  end

  @spec with_preloaded_order_user(%Query{}) :: %Query{}
  defp with_preloaded_order_user(%Query{} = query) do
    query
    |> join_orders_and_users()
    |> preload([order: o, user: u], [order: {o, [user: u]}])
  end

  @spec join_products(%Query{}) :: %Query{}
  defp join_products(%Query{} = query) do
    join_one(query, :suborder, :product)
  end

  @spec join_orders_and_users(%Query{}) :: %Query{}
  defp join_orders_and_users(%Query{} = query) do
    query
    |> join_orders()
    |> join_one(:order, :user)
  end

  @spec join_orders(%Query{}) :: %Query{}
  defp join_orders(%Query{} = query) do
    join_one(query, :suborder, :order)
  end
end
