defmodule CloudDbUi.Products.Product.Query do
  import Ecto.Query

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.{Product, ProductType}
  alias CloudDbUi.Orders.{Order, SubOrder}

  @doc """
  Names the concept of a base query.
  This is the constructor for the `Product.Query` module.
  """
  @spec base() :: %Ecto.Query{}
  def base(), do: from(p in Product, [as: :product])

  @doc """
  Preloads `:type`.
  """
  @spec with_preloaded_type(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_type(query \\ base()) do
    query
    |> join(
      :left,
      [product: p],
      t in ProductType,
      [on: p.product_type_id == t.id, as: :type]
    )
    |> preload([type: t], [product_type: t])
  end

  @doc """
  Preloads `:type`. Replaces `:orders` with order count.
  """
  @spec with_preloaded_type_and_order_count(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_type_and_order_count(query \\ base()) do
    query
    |> with_preloaded_type()
    |> group_by([type: t], [t.id])
    |> with_order_count()
  end

  @doc """
  Preloads `:type` and `:orders`. Each order has
  a preloaded `:user` and :suborders.
  """
  @spec with_preloaded_type_and_order_suborder_users(%Ecto.Query{}) ::
          %Ecto.Query{}
  def with_preloaded_type_and_order_suborder_users(query \\ base()) do
    query
    |> with_preloaded_type()
    |> join_suborders_and_orders()
    |> join(
      :left,
      [order: o],
      s in SubOrder,
      [on: s.order_id == o.id, as: :suborder]
    )
    |> join(
      :left,
      [order: o],
      u in User,
      [on: o.user_id == u.id, as: :user]
    )
    |> preload(
      [order: o, user: u, suborder: s],
      [orders: {o, [user: u, suborders: s]}]
    )
  end

  @doc """
  Orderable products. Preloads `:type`.
  """
  @spec orderable_with_preloaded_type(%Ecto.Query{}) :: %Ecto.Query{}
  def orderable_with_preloaded_type(query \\ base()) do
    query
    |> where([product: p], p.orderable == true)
    |> with_preloaded_type()
  end

  @doc """
  Replaces `:orders` with order count.
  """
  @spec with_order_count(%Ecto.Query{}) :: %Ecto.Query{}
  def with_order_count(query \\ base()) do
    query
    |> join_suborders_and_orders()
    |> join(
      :left,
      [suborder_with_product: s_p],
      po in Order,
      [on: s_p.order_id == po.id and not is_nil(po.paid_at), as: :paid_order]
    )
    |> group_by([product: p], [p.id])
    |> select_merge(
      [product: p, order: o, paid_order: po],
      %{orders: count(o, :distinct), paid_orders: count(po, :distinct)}
    )
  end

  # Joins all orders containing this product via its sub-orders.
  # Does not join the rest of the sub-orders of these orders.
  @spec join_suborders_and_orders(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_suborders_and_orders(query) do
    query
    |> join(
      :left,
      [product: p],
      s_p in SubOrder,
      [on: s_p.product_id == p.id, as: :suborder_with_product]
    )
    |> join(
      :left,
      [suborder_with_product: s_p],
      o in Order,
      [on: s_p.order_id == o.id, as: :order]
    )
  end
end
