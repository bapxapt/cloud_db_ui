defmodule CloudDbUi.ProductsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CloudDbUi.Products` context.
  """

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> add_product_type_id()
      |> Enum.into(%{
        description: "some description",
        image: "some image",
        name: "some name",
        unit_price: 120.5
      })
      |> CloudDbUi.Products.create_product()

    product
  end

  @doc """
  Generate a product_type.
  """
  def product_type_fixture(attrs \\ %{}) do
    {:ok, product_type} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: unique_type_name()
      })
      |> CloudDbUi.Products.create_product_type()

    product_type
  end

  # No need to create a new product type, since a product type ID is provided.
  @spec add_product_type_id(%{atom() => any()}) :: %{atom() => any()}
  defp add_product_type_id(%{product_type_id: _id} = attrs), do: attrs

  # Create an extra product type - it will be in the data base during testing.
  defp add_product_type_id(attrs) do
    Map.put(attrs, :product_type_id, product_type_fixture().id)
  end

  @spec unique_type_name() :: String.t()
  def unique_type_name(), do: "some type #{System.unique_integer()}"
end
