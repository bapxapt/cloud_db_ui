defmodule CloudDbUi.Orders.SubOrder.Query do
  import Ecto.Query

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Products.ProductType

  @doc """
  Names the concept of a base query. The constructor
  for the `SubOrder.Query` module.
  """
  @spec base() :: %Ecto.Query{}
  def base() do
    SubOrder
    |> from([as: :suborder])
    |> select_merge(
      [suborder: s],
      %{subtotal: fragment("ROUND(?, 2)", s.unit_price * s.quantity)}
    )
  end

  @doc """
  With specified IDs (primary key).
  """
  @spec for_ids(%Ecto.Query{}, [pos_integer()]) :: %Ecto.Query{}
  def for_ids(query \\ base(), ids) do
    where(query, [suborder: s], s.id in ^ids)
  end

  @doc """
  Belonging to a specific order.
  """
  @spec for_order(%Ecto.Query{}, %Order{}) :: %Ecto.Query{}
  def for_order(query \\ base(), %Order{} = order) do
    where(query, [suborder: s], s.order_id == ^order.id)
  end

  @doc """
  Belonging to a specific user. Fills the `paid` virtual field.
  """
  @spec for_user(%Ecto.Query{}, %User{}) :: %Ecto.Query{}
  def for_user(query \\ base(), %User{} = user) do
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
  @spec with_preloaded_order(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_order(query \\ base()) do
    query
    |> join_orders()
    |> preload([order: o], [order: o])
  end

  @doc """
  Preloads `:product` and `:order`. The `:order` has
  a preloaded `:user`. Fills the `:subtotal` virtual field.
  """
  @spec with_preloaded_product_and_order_user(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_product_and_order_user(query \\ base()) do
    query
    |> join_products()
    |> preload([product: p], [product: p])
    |> with_preloaded_order_user()
  end

  # TODO: get rid of :product_type in schema, just preload type in the :product

  @doc """
  Preloads `:order` and `:product`. The `:order` has a preloaded `:user`,
  the `:product` has a preloaded `:product_type`.
  Fills the `:subtotal` virtual field.
  """
  @spec with_full_preloads() :: %Ecto.Query{}
  def with_full_preloads() do
    base()
    |> with_preloaded_order_user()
    |> join_products()
    |> join(
      :left,
      [product: p],
      t in ProductType,
      [on: p.product_type_id == t.id, as: :type]
    )
    |> preload([product: p, type: t], [product: {p, [product_type: t]}])
  end

  @spec with_preloaded_order_user(%Ecto.Query{}) :: %Ecto.Query{}
  defp with_preloaded_order_user(query) do
    query
    |> join_orders_and_users()
    |> preload([order: o, user: u], [order: {o, [user: u]}])
  end

  @spec join_orders(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_orders(query) do
    join(
      query,
      :left,
      [suborder: s],
      o in Order,
      [on: s.order_id == o.id, as: :order]
    )
  end

  @spec join_products(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_products(query) do
    join(
      query,
      :left,
      [suborder: s],
      p in Product,
      [on: s.product_id == p.id, as: :product]
    )
  end

  @spec join_orders_and_users(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_orders_and_users(query) do
    query
    |> join_orders()
    |> join(
      :left,
      [order: o],
      u in User,
      [on: o.user_id == u.id, as: :user]
    )
  end
end
