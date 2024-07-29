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
  Generate an order.
  """
  @spec order_fixture(attrs()) :: %Order{}
  def order_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, &user_fixture/0)

    {:ok, order} =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.delete(:user)
      |> maybe_put_paid_at()
      |> CloudDbUi.Orders.create_order(user)

    order
  end

  @doc """
  Generate a suborder.
  """
  @spec suborder_fixture(attrs()) :: %SubOrder{}
  def suborder_fixture(attrs \\ %{}) do
    order = Map.get_lazy(attrs, :order, &order_fixture/0)
    product = Map.get_lazy(attrs, :product, &product_fixture/0)

    attrs_new =
      attrs
      |> Map.put(:order_id, order.id)
      |> Map.put(:product_id, product.id)
      |> Map.drop([:order, :product])
      |> Enum.into(%{quantity: 42, unit_price: 120.5})

    {:ok, suborder} =
      CloudDbUi.Orders.create_suborder(attrs_new, order, product)

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

  @spec maybe_put_paid_at(attrs()) :: attrs()
  defp maybe_put_paid_at(%{paid: true} = attrs) do
    Enum.into(attrs, %{paid_at: ~U[2020-01-01 00:00:00Z]})
  end

  # No `:paid` in `attrs`, or `:paid` is not `true`.
  defp maybe_put_paid_at(attrs), do: attrs
end
