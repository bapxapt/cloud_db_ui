defmodule CloudDbUi.ProductsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CloudDbUi.Products` context.
  """

  alias CloudDbUi.Products.{Product, ProductType}

  @type attrs() :: CloudDbUi.Type.attrs()

  @doc """
  Generate a product.
  """
  @spec product_fixture(attrs()) :: %Product{}
  def product_fixture(attrs \\ %{}) do
    type = Map.get_lazy(attrs, :product_type, &product_type_fixture/0)

    {:ok, product} =
      attrs
      |> Map.put(:product_type_id, type.id)
      |> Map.delete(:product_type)
      |> Enum.into(%{
        name: "some name",
        description: "some description",
        unit_price: 120.5,
        image: "some image"
      })
      |> CloudDbUi.Products.create_product(type)

    product
  end

  @doc """
  Generate a product_type.
  """
  @spec product_type_fixture(attrs()) :: %ProductType{}
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

  @spec unique_type_name() :: String.t()
  def unique_type_name(), do: "Type_#{System.unique_integer([:positive])}"
end
