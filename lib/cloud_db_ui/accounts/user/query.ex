defmodule CloudDbUi.Accounts.User.Query do
  import Ecto.Query

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Orders.SubOrder

  @doc """
  Names the concept of a base query.
  This is the constructor for the `User.Query` module.
  """
  @spec base() :: %Ecto.Query{}
  def base(), do: from(u in User, [as: :user])

  @doc """
  `%User{}`s with a specified `id`.
  """
  @spec with_id(%Ecto.Query{}, String.t()) :: %Ecto.Query{}
  def with_id(query \\ base(), id), do: where(query, [user: u], u.id == ^id)

  @doc """
  Preloads `:orders`. Each order has preloaded `:suborders`,
  and each sub-order has a preloaded `:product`.
  """
  @spec with_preloaded_order_suborder_products(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_order_suborder_products(query \\ base()) do
    query
    |> join_orders()
    |> join(
      :left,
      [order: o],
      s in SubOrder,
      [on: s.order_id == o.id, as: :suborder]
    )
    |> join(
      :left,
      [suborder: s],
      p in Product,
      [on: s.product_id == p.id, as: :product]
    )
    |> preload(
      [order: o, suborder: s, product: p],
      [orders: {o, [suborders: {s, [product: p]}]}]
    )
  end

  @doc """
  Replaces `:orders` with order count.
  Fills the `:paid_orders` virtual field.
  """
  @spec with_order_count(%Ecto.Query{}) :: %Ecto.Query{}
  def with_order_count(query \\ base()) do
    query
    |> with_filled_paid_orders()
    |> select_merge([order: o], %{orders: count(o)})
  end

  # Fills the `:paid_orders` virtual field.
  @spec with_filled_paid_orders(%Ecto.Query{}) :: %Ecto.Query{}
  defp with_filled_paid_orders(query) do
    query
    |> join_orders()
    |> group_by([user: u], [u.id])
    |> select_merge(
      [order: o],
      %{paid_orders: filter(count(o), not is_nil(o.paid_at))}
    )
  end

  @spec join_orders(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_orders(query) do
    join(
      query,
      :left,
      [user: u],
      o in Order,
      [on: o.user_id == u.id, as: :order]
    )
  end
end
