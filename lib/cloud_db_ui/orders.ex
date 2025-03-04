defmodule CloudDbUi.Orders do
  @moduledoc """
  The Orders context.
  """
  import Ecto.Query, warn: false

  alias CloudDbUi.Products.Product
  alias CloudDbUi.Repo
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias CloudDbUi.Accounts.User
  alias Flop.Meta
  alias Ecto.Changeset

  @type attrs() :: CloudDbUi.Type.attrs()
  @type db_id() :: CloudDbUi.Type.db_id()

  @doc """
  Return all orders with preloaded `:user` and `:suborders`.
  Each sub-order has a preloaded `:product`.
  Fills the `:total` virtual field.

  ## Examples

      iex> list_orders_with_full_preloads()
      {:ok, {[%Order{}, ...], %Meta{}}}

  """
  @spec list_orders_with_full_preloads(%Flop{}) ::
          {:ok, {[%Order{}], %Meta{}}} | {:error, %Meta{}}
  def list_orders_with_full_preloads(%Flop{} = flop \\ %Flop{}) do
    Order.Query.with_full_preloads()
    |> Flop.validate_and_run(flop, [for: Order])
    |> maybe_fill_subtotal_and_total()
  end

  @doc """
  Return all unpaid orders owned by a user. Preloads `:suborders`.
  Each sub-order has a preloaded `:product`.
  """
  @spec list_orders_unpaid_with_suborder_products(%User{}) :: [%Order{}]
  def list_orders_unpaid_with_suborder_products(%User{} = user) do
    user
    |> Order.Query.unpaid_with_preloaded_suborders_with_products()
    |> Repo.all()
  end

  @doc """
  Return all orders owned by a user. Preloads `:suborders`.
  Each sub-order has a preloaded `:product`.
  Fills the `:total` virtual field.
  """
  @spec list_orders_with_suborder_products(%Flop{}, %User{}) ::
          {:ok, {[%Order{}], %Meta{}}} | {:error, %Meta{}}
  def list_orders_with_suborder_products(%Flop{} = flop \\ %Flop{}, user) do
    user
    |> Order.Query.with_total_and_preloaded_suborders_with_products()
    |> Flop.validate_and_run(flop, [for: Order])
    |> maybe_fill_subtotal_and_total()
  end

  @doc """
  Return all suborders. Preloads `:product`, `:order`, and `:user`.
  Fills the `:subtotal` virtual field.
  """
  @spec list_suborders_with_product_and_order_user() :: [%SubOrder{}]
  def list_suborders_with_product_and_order_user() do
    SubOrder.Query.with_preloaded_product_and_order_user()
    |> Repo.all()
  end

  @doc """
  Get a single order. Preloads `:user`.
  """
  @spec get_order_with_user(db_id()) :: %Order{} | nil
  def get_order_with_user(id) do
    Order.Query.with_preloaded_user()
    |> Repo.get(id)
  end

  @doc """
  Get a single order with preloaded `:suborders` and `:user`.
  Each sub-order has a preloaded `:product`.
  Fills the `:total` virtual field.

  Raises `Ecto.NoResultsError` if the Order does not exist.

  ## Examples

      iex> get_order_with_full_preloads!(123)
      %Order{}

      iex> get_order_with_full_preloads!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_order_with_full_preloads!(db_id()) :: %Order{}
  def get_order_with_full_preloads!(id) do
    Order.Query.with_full_preloads()
    |> Repo.get!(id)
    |> Order.maybe_fill_subtotal_and_total()
  end

  @doc """
  Get a single order. Replaces `:suborders`. with a list
  of sub-order IDs.
  """
  @spec get_order_with_suborder_ids!(db_id()) :: %Order{}
  def get_order_with_suborder_ids!(id) do
    Order.Query.with_suborder_ids()
    |> Repo.get!(id)
  end

  @doc """
  Get a single order. Preloads `:suborders`.
  Each sub-order has a preloaded `:product`.
  """
  @spec get_order_with_suborder_products!(db_id()) :: %Order{}
  def get_order_with_suborder_products!(id) do
    Order.Query.with_preloaded_suborders_with_products()
    |> Repo.get!(id)
    |> Order.maybe_fill_subtotal_and_total()
  end

  @doc """
  Get a single order owned by a user. Preloads `:suborders`.
  Each sub-order has a preloaded `:product`.
  """
  @spec get_order_with_suborder_products!(db_id(), %User{}) :: %Order{}
  def get_order_with_suborder_products!(id, user) do
    user
    |> Order.Query.with_preloaded_suborders_with_products()
    |> Repo.get!(id)
    |> Order.maybe_fill_subtotal_and_total()
  end

  @doc """
  Get a single suborder. No preloads.

  Raises `Ecto.NoResultsError` if the SubOrder does not exist.

  ## Examples

      iex> get_suborder!(123)
      %SubOrder{}

      iex> get_suborder!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_suborder!(db_id()) :: %SubOrder{}
  def get_suborder!(suborder_id), do: Repo.get!(SubOrder, suborder_id)

  @doc """
  Get a single suborder belonging to a user.
  Fills the `paid` virtual field.
  """
  @spec get_suborder!(db_id(), %User{}) :: %SubOrder{}
  def get_suborder!(suborder_id, user) do
    user
    |> SubOrder.Query.for_user()
    |> Repo.get!(suborder_id)
  end

  @doc """
  Get a single suborder from an order that has preloaded `:suborders`.
  """
  @spec get_suborder_from_order!(%Order{}, db_id()) :: %SubOrder{}
  def get_suborder_from_order!(order, suborder_id) do
    case Order.get_suborder(order, suborder_id) do
      nil -> raise(%Ecto.NoResultsError{message: ""})
      suborder_found -> suborder_found
    end
  end

  @doc """
  Get a single suborder. Preloads `:order`.
  Fills the `:subtotal` and `paid` virtual fields.
  """
  @spec get_suborder_with_order!(db_id()) :: %SubOrder{}
  def get_suborder_with_order!(id) do
    SubOrder.Query.with_preloaded_order()
    |> Repo.get!(id)
  end

  @doc """
  Get a single suborder. Preloads `:order`, `:user`, `:product`, and
  `:product_type`. Fills the `:subtotal` and `paid` virtual fields.
  """
  @spec get_suborder_with_full_preloads!(db_id()) :: %SubOrder{}
  def get_suborder_with_full_preloads!(id) do
    SubOrder.Query.with_full_preloads()
    |> Repo.get!(id)
  end

  @doc """
  Get a single suborder. Preloads `:product` and `:order`.
  Fills the `:subtotal` virtual field.
  """
  @spec get_suborder_with_product_and_order_user!(db_id()) :: %SubOrder{}
  def get_suborder_with_product_and_order_user!(id) do
    SubOrder.Query.with_preloaded_product_and_order_user()
    |> Repo.get!(id)
  end

  @doc """
  Create an order.
  """
  @spec create_order(attrs(), %User{}) ::
          {:ok, %Order{}} | {:error, %Changeset{}}
  def create_order(attrs, user) do
    %Order{}
    |> Order.saving_changeset(attrs, user)
    |> Repo.insert()
  end

  @doc """
  Create a sub-order.

  ## Examples

      iex> create_suborder(order, product, 6)
      {:ok, %SubOrder{}}

      iex> create_suborder(order, product, -1)
      {:error, %Ecto.Changeset{}}

  """
  @spec create_suborder(%Order{}, %Product{}, pos_integer()) ::
          {:ok, %SubOrder{}} | {:error, %Changeset{}}
  def create_suborder(%Order{} = order, %Product{} = product, quantity) do
    %{
      order_id: order.id,
      product_id: product.id,
      unit_price: product.unit_price,
      quantity: quantity
    }
    |> create_suborder(order, product)
  end

  # Create a sub-order as an admin.
  @spec create_suborder(attrs(), %Order{} | nil, %Product{} | nil) ::
          {:ok, %Order{}} | {:error, %Changeset{}}
  def create_suborder(attrs, %Order{} = order, %Product{} = product) do
    %SubOrder{}
    |> SubOrder.saving_changeset(attrs, order, product)
    |> Repo.insert()
  end

  @doc """
  Update an order via a form component as an admin.

  ## Examples

      iex> update_order(order, %{field: new_value}, user)
      {:ok, %Order{}}

      iex> update_order(order, %{field: bad_value}, user)
      {:error, %Ecto.Changeset{}}

  """
  @spec update_order(%Order{}, attrs(), %User{}) ::
          {:ok, %Order{}} | {:error, %Changeset{}}
  def update_order(%Order{} = order, attrs, user) do
    order
    |> Order.saving_changeset(attrs, user)
    |> Repo.update()
  end

  @spec payment_changeset(%Order{}) :: %Changeset{}
  def payment_changeset(%Order{} = order) do
    Order.payment_changeset(order)
  end

  @doc """
  Only calls `Repo.update()` on a passed payment `changeset`.

  Changeset validity check happens outside in
  `CloudDbUiWeb.OrderLive.PayComponent.pay_for_order()`.
  """
  @spec pay_for_order(%Changeset{}) :: {:ok, %Order{}} | {:error, %Changeset{}}
  def pay_for_order(%Changeset{} = changeset), do: Repo.update(changeset)

  @doc """
  Update a sub-order.

  ## Examples

      iex> update_suborder(suborder, %{field: new_value}, order, product)
      {:ok, %SubOrder{}}

      iex> update_suborder(suborder, %{field: bad_value}, order, product)
      {:error, %Ecto.Changeset{}}

  """
  def update_suborder(%SubOrder{} = suborder, attrs, order, product) do
    suborder
    |> SubOrder.saving_changeset(attrs, order, product)
    |> Repo.update()
  end

  @doc """
  Replace `:quantity` of a sub-order.
  """
  @spec update_suborder_quantity(%SubOrder{}, attrs()) ::
          {:ok, %SubOrder{}} | {:error, %Changeset{}}
  def update_suborder_quantity(%SubOrder{} = suborder, attrs) do
    suborder
    |> SubOrder.quantity_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete an unpaid order.

  ## Examples

      iex> delete_order(order)
      {:ok, %Order{}}

      iex> delete_order(order)
      {:error, %Ecto.Changeset{}}

  """
  def delete_order(%Order{} = order) do
    order
    |> Order.deletion_changeset()
    |> Repo.delete()
  end

  @doc """
  Delete a sub-order (an order position) of an unpaid order.

  ## Examples

      iex> delete_suborder(suborder, order)
      {:ok, %SubOrder{}}

      iex> delete_suborder(suborder, order)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_suborder(%SubOrder{}, %Order{}) ::
          {:ok, %SubOrder{}} | {:error, %Changeset{}}
  def delete_suborder(%SubOrder{} = suborder, %Order{} = order) do
    suborder
    |> SubOrder.deletion_changeset(order)
    |> Repo.delete()
  end

  @spec delete_suborders(%Order{}) :: {non_neg_integer(), nil | [%SubOrder{}]}
  def delete_suborders(%Order{} = order) do
    order
    |> SubOrder.Query.for_order()
    |> Repo.delete_all()
  end

  @spec delete_suborders([pos_integer()]) ::
          {non_neg_integer(), nil | [%SubOrder{}]}
  def delete_suborders(ids) when is_list(ids) do
    ids
    |> SubOrder.Query.for_ids()
    |> Repo.delete_all()
  end

  @doc """
  Return an `%Ecto.Changeset{}` for tracking order changes.

  ## Examples

      iex> change_order(order)
      %Ecto.Changeset{data: %Order{}}

  """
  @spec change_order(%Order{}, attrs(), %User{} | nil) :: %Changeset{}
  def change_order(%Order{} = order, attrs \\ %{}, user \\ nil) do
    Order.validation_changeset(order, attrs, user)
  end

  @doc """
  Return an `%Ecto.Changeset{}` for tracking suborder changes.

  ## Examples

      iex> change_suborder(suborder)
      %Ecto.Changeset{data: %SubOrder{}}

  """
  @spec change_suborder(
          %SubOrder{},
          attrs(),
          %Order{} | nil,
          %Product{} | nil
        ) :: %Changeset{}
  def change_suborder(
        %SubOrder{} = suborder,
        attrs \\ %{},
        order \\ nil,
        product \\ nil
      ) do
    SubOrder.validation_changeset(suborder, attrs, order, product)
  end

  @spec change_suborder_quantity(%SubOrder{}, attrs()) :: %Changeset{}
  def change_suborder_quantity(%SubOrder{} = suborder, attrs \\ %{}) do
    SubOrder.quantity_changeset(suborder, attrs)
  end

  @spec maybe_fill_subtotal_and_total({:ok, {[%Order{}], %Meta{}}}) ::
          {:ok, {[%Order{}], %Meta{}}}
  defp maybe_fill_subtotal_and_total({:ok, {orders, meta}}) do
    {:ok, {Enum.map(orders, &Order.maybe_fill_subtotal_and_total/1), meta}}
  end

  @spec maybe_fill_subtotal_and_total({:error, %Meta{}}) :: {:error, %Meta{}}
  defp maybe_fill_subtotal_and_total({:error, meta}), do: {:error, meta}
end
