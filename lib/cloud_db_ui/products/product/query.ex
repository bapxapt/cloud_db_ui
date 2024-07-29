defmodule CloudDbUi.Products.Product.Query do
  import CloudDbUi.Query
  import Ecto.Query

  @doc """
  Names the concept of a base query. The constructor for this module.
  """
  @spec base() :: %Ecto.Query{}
  def base(), do: from(p in CloudDbUi.Products.Product, [as: :product])

  @doc """
  Preloads `:product_type`.
  """
  @spec with_preloaded_type(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_type(query \\ base()) do
    query
    |> join_one(:product, :product_type)
    |> preload([product_type: t], [product_type: t])
  end

  @doc """
  Preloads `:product_type`. Replaces `:orders` with order count.
  """
  @spec with_preloaded_type_and_order_count(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_type_and_order_count(query \\ base()) do
    query
    |> with_preloaded_type()
    |> group_by([product_type: t], [t.id])
    |> with_order_count()
  end

  @doc """
  Orderable products. Preloads `:product_type`.
  """
  @spec orderable_with_preloaded_type(%Ecto.Query{}) :: %Ecto.Query{}
  def orderable_with_preloaded_type(query \\ base()) do
    query
    |> where([product: p], p.orderable == true)
    |> with_preloaded_type()
    |> group_by([product: p, product_type: t], [p.id, t.id])
  end

  @doc """
  Preloads `:product_type` and `:orders`. Each order has
  a preloaded `:user` and :suborders.
  """
  @spec with_preloaded_type_and_order_suborder_users(%Ecto.Query{}) ::
          %Ecto.Query{}
  def with_preloaded_type_and_order_suborder_users(query \\ base()) do
    query
    |> with_preloaded_type()
    |> join_suborders_and_orders()
    |> join_one(:order, :user)
    |> preload(
      [order: o, user: u, suborder: s],
      [orders: {o, [user: u, suborders: s]}]
    )
  end

  @doc """
  Replaces `:orders` with order count.
  """
  @spec with_order_count(%Ecto.Query{}) :: %Ecto.Query{}
  def with_order_count(query \\ base()) do
    query
    |> join_suborders_and_orders()
    |> group_by([product: p], [p.id])
    |> select_merge([order: o], %{orders: count(o, :distinct)})
    |> select_merge(
      [order: o],
      %{paid_orders: filter(count(o, :distinct), not is_nil(o.paid_at))}
    )
  end

  # Join all orders containing this product via its sub-orders.
  # Does not join the rest of the sub-orders of these orders.
  @spec join_suborders_and_orders(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_suborders_and_orders(query) do
    query
    |> join_many(:product, :suborders, :suborder)
    |> join_one(:suborder, :order)
  end
end
