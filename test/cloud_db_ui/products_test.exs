defmodule CloudDbUi.ProductsTest do
  use CloudDbUi.DataCase

  alias CloudDbUi.Products

  describe "products" do
    alias CloudDbUi.Products.Product

    import CloudDbUi.ProductsFixtures

    @invalid_attrs %{description: nil, image: nil, name: nil, unit_price: nil}

    test "list_products/0 returns all products" do
      product = product_fixture()

      assert Products.list_products() == [product]
    end

    # TODO: list_products_with_type_and_order_count
    test "list_products_with_preloaded_type/0 returns all with preloads" do
      type = product_type_fixture()

      product =
        %{product_type_id: type.id}
        |> product_fixture()
        |> Map.replace!(:type, type)

      assert Products.list_products_with_preloaded_type() == [product]
    end

    test "get_product!/1 returns the product with given id" do
      product = product_fixture()

      assert Products.get_product!(product.id) == product
    end

    test "get_product_with_type_and_order_users!/1 returns with preloads" do
      type = product_type_fixture()

      product =
        %{product_type_id: type.id}
        |> product_fixture()
        |> Map.replace!(:type, type)

      # TODO: line length
      assert Products.get_product_with_type_and_order_users!(product.id) == product
    end

    test "create_product/1 with valid data creates a product" do
      type = product_type_fixture()

      valid_attrs = %{
        product_type_id: type.id,
        description: "some description",
        image: "some image",
        name: "some name",
        unit_price: 120.5
      }

      assert {:ok, %Product{} = product} = Products.create_product(valid_attrs)
      assert product.description == "some description"
      assert product.image_path == "some image"
      assert product.name == "some name"
      assert product.unit_price == 120.5
      assert product.product_type_id == type.id
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Products.create_product(@invalid_attrs)
    end

    test "update_product/2 with valid data updates the product" do
      product = product_fixture()

      update_attrs = %{
        description: "some updated description",
        image: "some updated image",
        name: "some updated name",
        unit_price: 456.7
      }

      assert {:ok, %Product{} = product} = Products.update_product(product, update_attrs)
      assert product.description == "some updated description"
      assert product.image_path == "some updated image"
      assert product.name == "some updated name"
      assert product.unit_price == 456.7
    end

    test "update_product/2 with invalid data returns error changeset" do
      product = product_fixture()

      assert {:error, %Ecto.Changeset{}} = Products.update_product(product, @invalid_attrs)
      assert product == Products.get_product!(product.id)
    end

    test "delete_product/1 deletes the product" do
      product = product_fixture()

      assert {:ok, %Product{}} = Products.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Products.get_product!(product.id) end
    end

    test "change_product/1 returns a product changeset" do
      product = product_fixture()

      assert %Ecto.Changeset{} = Products.change_product(product)
    end
  end

  describe "product_types" do
    alias CloudDbUi.Products.ProductType

    import CloudDbUi.ProductsFixtures

    @invalid_attrs %{description: nil, name: nil}

    test "list_product_types/0 returns all product_types" do
      product_type = product_type_fixture()

      assert Products.list_product_types() == [product_type]
    end

    test "get_product_type!/1 returns the product_type with given id" do
      product_type = product_type_fixture()
      assert Products.get_product_type!(product_type.id) == product_type
    end

    test "create_product_type/1 with valid data creates a product_type" do
      valid_attrs = %{description: "some description", name: "some name"}

      assert {:ok, %ProductType{} = product_type} = Products.create_product_type(valid_attrs)
      assert product_type.description == "some description"
      assert product_type.name == "some name"
    end

    test "create_product_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Products.create_product_type(@invalid_attrs)
    end

    test "update_product_type/2 with valid data updates the product_type" do
      product_type = product_type_fixture()
      update_attrs = %{description: "some updated description", name: "some updated name"}

      assert {:ok, %ProductType{} = product_type} = Products.update_product_type(product_type, update_attrs)
      assert product_type.description == "some updated description"
      assert product_type.name == "some updated name"
    end

    test "update_product_type/2 with invalid data returns error changeset" do
      product_type = product_type_fixture()
      assert {:error, %Ecto.Changeset{}} = Products.update_product_type(product_type, @invalid_attrs)
      assert product_type == Products.get_product_type!(product_type.id)
    end

    test "delete_product_type/1 deletes the product_type" do
      product_type = product_type_fixture()
      assert {:ok, %ProductType{}} = Products.delete_product_type(product_type)
      assert_raise Ecto.NoResultsError, fn -> Products.get_product_type!(product_type.id) end
    end

    test "change_product_type/1 returns a product_type changeset" do
      product_type = product_type_fixture()
      assert %Ecto.Changeset{} = Products.change_product_type(product_type)
    end
  end
end
