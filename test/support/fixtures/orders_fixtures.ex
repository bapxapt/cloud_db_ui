defmodule CloudDbUi.OrdersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CloudDbUi.Orders` context.
  """

  import CloudDbUi.{AccountsFixtures, ProductsFixtures}

  @doc """
  Generate an order.
  """
  def order_fixture(attrs \\ %{}) do
    {:ok, order} =
      attrs
      |> maybe_add_user_id()
      |> Enum.into(%{paid_at: ~U[2024-01-01T00:00:00.000+00]})
      |> CloudDbUi.Orders.create_order()

    order
  end

  @doc """
  Generate a suborder.
  """
  def suborder_fixture(attrs \\ %{}) do
    {:ok, suborder} =
      attrs
      |> maybe_add_order_id()
      |> maybe_add_product_id()
      |> Enum.into(%{quantity: 42, unit_price: 120.5})
      |> CloudDbUi.Orders.create_suborder()

    suborder
  end

  # No need to create a new user, since a user ID is provided.
  @spec maybe_add_user_id(%{atom() => any()}) :: %{atom() => any()}
  defp maybe_add_user_id(%{user_id: _id} = attrs), do: attrs

  # Create an extra user - it will be in the data base during testing.
  defp maybe_add_user_id(attrs) do
    Map.put(attrs, :user_id, user_fixture().id)
  end

  # No need to create a new order, since an order ID is provided.
  @spec maybe_add_order_id(%{atom() => any()}) :: %{atom() => any()}
  defp maybe_add_order_id(%{order_id: _id} = attrs), do: attrs

  # Create an extra order - it will be in the data base during testing.
  defp maybe_add_order_id(attrs) do
    Map.put(attrs, :order_id, order_fixture().id)
  end

  # No need to create a new product, since a product ID is provided.
  @spec maybe_add_product_id(%{atom() => any()}) :: %{atom() => any()}
  defp maybe_add_product_id(%{product_id: _id} = attrs), do: attrs

  # Create an extra product - it will be in the data base during testing.
  defp maybe_add_product_id(attrs) do
    Map.put(attrs, :product_id, product_fixture().id)
  end
end
