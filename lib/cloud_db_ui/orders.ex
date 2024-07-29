defmodule CloudDbUi.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false

  alias CloudDbUi.Products.Product
  alias CloudDbUi.Repo
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUi.Accounts.User

  @type attrs :: CloudDbUi.Type.attrs()
  @type db_id :: CloudDbUi.Type.db_id()

  @doc """
  Return all orders with preloaded `:user` and `:suborders`.
  Each sub-order has a preloaded `:product`.
  `%Order{}`s are ordered in descending order by `:paid_at`.

  ## Examples

      iex> list_orders_with_full_preloads()
      [%Order{}, ...]

  """
  def list_orders_with_full_preloads() do
    Order.Query.with_full_preloads()
    |> Repo.all()
    |> fill_virtual_fields()
  end

  @doc """
  Return all unpaid orders owned by a user. Preloads `:suborders`.
  Each sub-order has a preloaded `:product`.
  """
  @spec list_orders_unpaid_with_suborder_products(%User{}) :: [%Order{}]
  def list_orders_unpaid_with_suborder_products(user) do
    user
    |> Order.Query.unpaid_with_preloaded_suborders_with_products()
    |> Repo.all()
  end

  @doc """
  Return all orders owned by a user. Preloads `:suborders`.
  Each sub-order has a preloaded `:product`.
  """
  @spec list_orders_with_suborder_products(%User{}) :: [%Order{}]
  def list_orders_with_suborder_products(user) do
    user
    |> Order.Query.with_preloaded_suborders_with_products()
    |> Repo.all()
    |> fill_virtual_fields()
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
    |> fill_virtual_fields()
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
    |> fill_virtual_fields()
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
    |> fill_virtual_fields()
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
  Create an order by clicking an "Order" button as a user.

  ## Examples

      iex> create_order(%{field: value})
      {:ok, %Order{}}

      iex> create_order(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_order(attrs \\ %{}) do
    %Order{}
    |> Order.creation_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Create an order as an admin.
  """
  @spec create_order(attrs(), %User{}) ::
          {:ok, %Order{}} | {:error, %Ecto.Changeset{}}
  def create_order(attrs, user) do
    %Order{}
    |> Order.saving_changeset(attrs, user)
    |> Repo.insert()
  end

  @doc """
  Create a sub-order.

  ## Examples

      iex> create_suborder(%{field: value})
      {:ok, %SubOrder{}}

      iex> create_suborder(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_suborder(attrs \\ %{}) do
    %SubOrder{}
    |> SubOrder.creation_changeset(attrs)
    |> Repo.insert()
  end

  @spec create_suborder(%Order{}, %Product{}, pos_integer()) ::
          {:ok, %SubOrder{}} | {:error, %Ecto.Changeset{}}
  def create_suborder(%Order{} = order, %Product{} = product, quantity) do
    create_suborder(%{
      order_id: order.id,
      product_id: product.id,
      unit_price: product.unit_price,
      quantity: quantity
    })
  end

  @doc """
  Create a sub-order as an admin.
  """
  @spec create_suborder(attrs(), %Order{}, %Product{}) ::
          {:ok, %Order{}} | {:error, %Ecto.Changeset{}}
  def create_suborder(attrs, order, product) do
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
          {:ok, %Order{}} | {:error, %Ecto.Changeset{}}
  def update_order(%Order{} = order, attrs, user) do
    order
    |> Order.saving_changeset(attrs, user)
    |> Repo.update()
  end

  def payment_changeset(%Order{} = order, attrs) do
    Order.payment_changeset(order, attrs)
  end

  @doc """
  If an `%Ecto.Changeset{}` is passed, only calls `Repo.update()` on it.
  This means changeset validity check must happen outside
  (for example, in `CloudDbUiWeb.OrderLive.PayComponent.pay_for_order()`).

  If an `%Order{}` is passed, returns an `%Ecto.Changeset{}`
  for tracking order changes.
  """
  def pay_for_order(%Ecto.Changeset{} = changeset), do: Repo.update(changeset)

  def pay_for_order(%Order{} = order), do: payment_changeset(order, %{})

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
          {:ok, %SubOrder{}} | {:error, %Ecto.Changeset{}}
  def update_suborder_quantity(%SubOrder{} = suborder, attrs) do
    suborder
    |> SubOrder.quantity_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete an order.

  ## Examples

      iex> delete_order(order)
      {:ok, %Order{}}

      iex> delete_order(order)
      {:error, %Ecto.Changeset{}}

  """
  def delete_order(%Order{} = order), do: Repo.delete(order)

  @doc """
  Delete a sub-order.

  ## Examples

      iex> delete_suborder(suborder)
      {:ok, %SubOrder{}}

      iex> delete_suborder(suborder)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_suborder(%SubOrder{}) ::
          {:ok, %SubOrder{}} | {:error, %Ecto.Changeset{}}
  def delete_suborder(%SubOrder{} = suborder), do: Repo.delete(suborder)

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
  def change_order(%Order{} = order, attrs \\ %{}, user \\ nil) do
    Order.validation_changeset(order, attrs, user)
  end

  @doc """
  Return an `%Ecto.Changeset{}` for tracking suborder changes.

  ## Examples

      iex> change_suborder(suborder)
      %Ecto.Changeset{data: %SubOrder{}}

  """
  def change_suborder(
        %SubOrder{} = suborder,
        attrs \\ %{},
        order \\ nil,
        product \\ nil
      ) do
    SubOrder.validation_changeset(suborder, attrs, order, product)
  end

  def change_suborder_quantity(%SubOrder{} = suborder, attrs \\ %{}) do
    SubOrder.quantity_changeset(suborder, attrs)
  end

  @spec fill_virtual_fields([%Order{}]) :: [%Order{}]
  defp fill_virtual_fields(orders) when is_list(orders) do
    Enum.map(orders, &fill_virtual_fields/1)
  end

  @spec fill_virtual_fields(%Order{}) :: %Order{}
  defp fill_virtual_fields(%Order{} = order) when is_list(order.suborders) do
    order
    |> Map.replace(
      :suborders,
      Enum.map(order.suborders, &SubOrder.fill_subtotal/1)
    )
    |> Order.fill_total()
  end
end
