defmodule CloudDbUi.OrdersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CloudDbUi.Orders` context.
  """

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.{Order, SubOrder}

  import CloudDbUi.{AccountsFixtures, ProductsFixtures}

  @type attrs() :: CloudDbUi.Type.attrs()

  @doc """
  Generate an unpaid order.
  """
  @spec order_fixture(attrs()) :: %Order{}
  def order_fixture(attrs \\ %{}) do
    {:ok, order} =
      attrs
      |> maybe_add_user_id()
      |> CloudDbUi.Orders.create_order()

    order
  end

  @doc """
  Generate a paid order.
  """
  @spec order_paid_fixture(attrs()) :: %Order{}
  def order_paid_fixture(attrs \\ %{}) do
    attrs
    |> maybe_put_paid_at()
    |> Map.put(:paid, true)
    |> order_fixture()
  end

  @doc """
  Generate a suborder.
  """
  @spec suborder_fixture(attrs()) :: %SubOrder{}
  def suborder_fixture(attrs \\ %{}) do
    {:ok, suborder} =
      attrs
      |> maybe_add_order_id()
      |> maybe_add_product_id()
      |> Enum.into(%{quantity: 42, unit_price: Decimal.new("120.50")})
      |> CloudDbUi.Orders.create_suborder()

    suborder
  end

  @doc """
  Replace `:suborder`, `:total`, and `:user` (if a `user` is passed)
  fields in an `%Order{}` created with `order_fixture()`.
  """
  @spec replace_order_fields(%Order{}, %SubOrder{}) :: %Order{}
  def replace_order_fields(order, %SubOrder{} = suborder) do
    order
    |> Map.replace!(:suborders, [suborder])
    |> Map.replace!(:total, suborder.subtotal)
  end

  @spec replace_order_fields(%Order{}, %SubOrder{}, %User{}) :: %Order{}
  def replace_order_fields(order, %SubOrder{} = suborder, %User{} = user) do
    order
    |> replace_order_fields(suborder)
    |> Map.replace!(:user, user)
  end

  @doc """
  Replace `:subtotal` and `:product` (if a `product` is passed) fields
  in a `%SubOrder{}` created with `suborder_fixture()`.
  """
  @spec replace_suborder_fields(%SubOrder{}) :: %SubOrder{}
  def replace_suborder_fields(suborder) do
    Map.replace!(
      suborder,
      :subtotal,
      Decimal.mult(suborder.unit_price, suborder.quantity)
    )
  end

  @spec replace_suborder_fields(%SubOrder{}, %Product{}) :: %SubOrder{}
  def replace_suborder_fields(suborder, %Product{} = product) do
    suborder
    |> replace_suborder_fields()
    |> Map.replace!(:product, product)
  end

  # No need to create a new user, since a user ID is provided.
  @spec maybe_add_user_id(attrs()) :: attrs()
  defp maybe_add_user_id(%{user_id: _id} = attrs), do: attrs

  # Create an extra user - it will be in the data base during testing.
  defp maybe_add_user_id(attrs) do
    Map.put(attrs, :user_id, user_fixture().id)
  end

  # No need to create a new order, since an order ID is provided.
  @spec maybe_add_order_id(attrs()) :: attrs()
  defp maybe_add_order_id(%{order_id: _id} = attrs), do: attrs

  # Create an extra order - it will be in the data base during testing.
  defp maybe_add_order_id(attrs) do
    Map.put(attrs, :order_id, order_fixture().id)
  end

  # No need to create a new product, since a product ID is provided.
  @spec maybe_add_product_id(attrs()) :: attrs()
  defp maybe_add_product_id(%{product_id: _id} = attrs), do: attrs

  # Create an extra product - it will be in the data base during testing.
  defp maybe_add_product_id(attrs) do
    Map.put(attrs, :product_id, product_fixture().id)
  end

  @spec maybe_put_paid_at(attrs()) :: attrs()
  defp maybe_put_paid_at(%{paid_at: at} = attrs) when at != nil, do: attrs

  # No `:paid_at` in `attrs`, or `:paid_at` is nil.
  defp maybe_put_paid_at(attrs) do
    Map.put(attrs, :paid_at, ~U[2020-01-01T00:00:00.000+00])
  end
end
