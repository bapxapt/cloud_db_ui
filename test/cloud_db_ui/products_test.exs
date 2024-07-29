defmodule CloudDbUi.ProductsTest do
  use CloudDbUi.DataCase

  alias CloudDbUi.Products

  describe "products" do
    alias CloudDbUi.Products.Product

    import CloudDbUi.{ProductsFixtures, OrdersFixtures, AccountsFixtures}

    @invalid_attrs %{name: nil, unit_price: nil}

    test "list_products/0 returns all products" do
      product = product_fixture()

      assert Products.list_products() == [product]
    end

    # For Index as an administrator.
    test "list_products_with_type_and_order_count/0 returns all w/ preloads" do
      type = product_type_fixture()
      order = order_fixture()

      product =
        %{product_type_id: type.id}
        |> product_fixture()
        |> Map.replace!(:product_type, type)
        |> Map.replace!(:orders, 1)

      suborder_fixture(%{order_id: order.id, product_id: product.id})

      assert Products.list_products_with_type_and_order_count() == [product]
    end

    # For Index as a user or as a guest.
    test "list_orderable_products_with_type/0 returns orderable products" do
      type = product_type_fixture()

      product_fixture(%{product_type_id: type.id, orderable: false})

      orderable =
        %{product_type_id: type.id}
        |> product_fixture()
        |> Map.replace!(:product_type, type)

      assert Products.list_orderable_products_with_type() == [orderable]
    end

    test "get_product!/1 returns the product with given id" do
      product = product_fixture()

      assert Products.get_product!(product.id) == product
    end

    # For Show as an administrator.
    test "get_product_with_type_and_order_users!/1 returns with preloads" do
      user = user_fixture()
      order = order_fixture(%{user_id: user.id})
      type = product_type_fixture()

      product =
        %{product_type_id: type.id}
        |> product_fixture()
        |> Map.replace!(:product_type, type)
        |> Map.replace!(:orders, [Map.replace!(order, :user, user)])

      suborder_fixture(%{order_id: order.id, product_id: product.id})

      assert Products.get_product_with_type_and_order_users!(product.id) == product
    end

    # For Show as a user or as a guest.
    test "get_orderable_product_with_type!/1 returns an orderable product" do
      type = product_type_fixture()

      non_orderable =
        product_fixture(%{product_type_id: type.id, orderable: false})

      orderable =
        %{product_type_id: type.id}
        |> product_fixture()
        |> Map.replace!(:product_type, type)

      assert Products.get_orderable_product_with_type!(orderable.id) == orderable

      assert_raise Ecto.NoResultsError, fn ->
        Products.get_orderable_product_with_type!(non_orderable.id)
      end
    end

    test "create_product/1 with valid data creates a product" do
      type = product_type_fixture()

      valid_attrs = %{
        product_type_id: type.id,
        description: "some description",
        image_path: "some path",
        name: "some name",
        unit_price: Decimal.new("120.50")
      }

      assert {:ok, %Product{} = product} = Products.create_product(valid_attrs)
      assert product.description == "some description"
      assert product.image_path == "some path"
      assert product.name == "some name"
      assert product.unit_price == Decimal.new("120.50")
      assert product.product_type_id == type.id
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Products.create_product(@invalid_attrs)
    end

    test "update_product/2 with valid data updates the product" do
      product = product_fixture()

      attrs = %{
        description: "some updated description",
        image_path: "some updated path",
        name: "some updated name",
        unit_price: Decimal.new("456.70")
      }

      assert {:ok, %Product{} = product} = Products.update_product(product, attrs)
      assert product.description == "some updated description"
      assert product.image_path == "some updated path"
      assert product.name == "some updated name"
      assert product.unit_price == Decimal.new("456.70")
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
