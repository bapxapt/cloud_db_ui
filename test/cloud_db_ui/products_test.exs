defmodule CloudDbUi.ProductsTest do
  use CloudDbUi.DataCase

  alias CloudDbUi.Products
  alias CloudDbUi.Orders
  alias Ecto.Changeset
  alias Flop.Meta

  describe "products" do
    alias CloudDbUi.Products.Product

    import CloudDbUi.{ProductsFixtures, OrdersFixtures, AccountsFixtures}

    @valid_attrs %{
      name: "some name",
      description: "some description",
      unit_price: 121.5,
      image_path: "some path"
    }

    @update_attrs %{
      name: "some updated name",
      description: "some updated description",
      unit_price: 456.7,
      image_path: "some updated path"
    }

    @invalid_attrs %{name: nil, product_type_id: nil, unit_price: nil}

    setup do
      type = product_type_fixture()

      %{type: type, product: product_fixture(%{product_type: type})}
    end

    # For Index as an administrator.
    test "list_products_with_type_and_order_count/0 returns all w/ preloads",
         %{type: type, product: product} do
      order = order_fixture()

      suborder_fixture(%{order: order, product: product})

      product_new =
        product
        |> Map.replace!(:product_type, type)
        |> Map.replace!(:orders, 1)
        |> Map.replace!(:paid_orders, 0)

      {:ok, {products, %Meta{}}} =
        Products.list_products_with_type_and_order_count()

      assert(products == [product_new])
    end

    # For Index as a user or as a guest.
    test "list_orderable_products_with_type/0 returns orderable products",
         %{type: type, product: product} do
      product_fixture(%{product_type: type, orderable: false})

      {:ok, {products, %Meta{}}} = Products.list_orderable_products_with_type()

      assert(products == [Map.replace!(product, :product_type, type)])
    end

    test "get_product!/1 returns the product with given id",
         %{product: product} do
      assert(Products.get_product!(product.id) == product)
    end

    # For Show as an administrator.
    test "get_product_with_type_and_order_suborder_users!/1 gets preloads",
         %{type: type, product: product} do
      user = user_fixture()
      order = order_fixture(%{user: user})
      suborder = suborder_fixture(%{order: order, product: product})

      product_new =
        product
        |> Map.replace!(:product_type, type)
        |> Map.replace!(:orders, [replace_order_fields(order, suborder, user)])

      product.id
      |> Products.get_product_with_type_and_order_suborder_users!()
      |> Kernel.==(product_new)
      |> assert()
    end

    # For Show as a user or as a guest.
    test "get_orderable_product_with_type!/1 returns an orderable product",
         %{type: type, product: product} do
      orderable = Map.replace!(product, :product_type, type)
      non_orderable = product_fixture(%{product_type: type, orderable: false})

      orderable.id
      |> Products.get_orderable_product_with_type!()
      |> Kernel.==(orderable)
      |> assert()

      assert_raise(Ecto.NoResultsError, fn ->
        Products.get_orderable_product_with_type!(non_orderable.id)
      end)
    end

    test "create_product/2 with valid data creates a product", %{type: type} do
      {:ok, %Product{} = product} =
        @valid_attrs
        |> Map.put(:product_type_id, type.id)
        |> Products.create_product(type)

      assert(product.name == "some name")
      assert(product.product_type_id == type.id)
      assert(product.description == "some description")
      assert(product.unit_price == Decimal.new("121.50"))
      assert(product.image_path == "some path")
    end

    test "create_product/2 with a blank description nilifies it",
         %{type: type} do
      {:ok, %Product{} = product} =
        %{product_type_id: type.id, description: " "}
        |> Enum.into(@valid_attrs)
        |> Products.create_product(type)

      assert(product.description == nil)
    end

    test "create_product/2 with invalid data returns an error changeset",
         %{type: type} do
      errs =
        @invalid_attrs
        |> Products.create_product(type)
        |> errors_on()

      assert(errs.name == ["can't be blank"])
      assert(errs.product_type_id == ["can't be blank"])
      assert(errs.unit_price == ["can't be blank"])
    end

    test "create_product/2 of an unassignable type returns a changeset" do
      unassignable = product_type_fixture(%{assignable: false})

      errs =
        Products.create_product(
          Map.put_new(@valid_attrs, :product_type_id, unassignable.id),
          unassignable
        )
        |> errors_on()

      assert(errs.product_type_id == ["the product type is not assignable"])
    end

    test "update_product/3 with valid data updates a product",
         %{product: product} do
      type_new = product_type_fixture()

      {:ok, %Product{} = updated} =
        Products.update_product(
          product,
          Map.put_new(@update_attrs, :product_type_id, type_new.id),
          type_new
        )

      assert(updated.name == "some updated name")
      assert(updated.product_type_id == type_new.id)
      assert(updated.description == "some updated description")
      assert(updated.unit_price == Decimal.new("456.70"))
      assert(updated.image_path == "some updated path")
    end

    test "update_product/3 with a blank description nilifies it",
         %{product: product, type: type} do
      {:ok, %Product{} = updated} =
        Products.update_product(
          product,
          Enum.into(%{product_type_id: type.id, description: " "}, @update_attrs),
          type
        )

      assert(updated.description == nil)

      {:ok, %Product{} = with_blank_desc} =
        update_bypassing_context(product_fixture(), %{description: " "})

      assert(with_blank_desc.description == " ")

      {:ok, %Product{} = with_nil_desc} =
        Products.update_product(
          with_blank_desc,
          %{unit_price: with_blank_desc.unit_price},
          type
        )

      assert(with_nil_desc.description == nil)
    end

    test "update_product/3 with invalid data returns an error changeset",
         %{product: product} do
      errs =
        product
        |> Products.update_product(@invalid_attrs, nil)
        |> errors_on()

      assert(errs.name == ["can't be blank"])
      assert(errs.product_type_id == ["can't be blank"])
      assert(errs.unit_price == ["can't be blank"])
      assert(product == Products.get_product!(product.id))
    end

    test "update_product/3 to have an unassignable type returns a changeset",
         %{product: product} do
      unassignable = product_type_fixture(%{assignable: false})

      errs =
        Products.update_product(
          product,
          Map.put_new(@update_attrs, :product_type_id, unassignable.id),
          unassignable
        )
        |> errors_on()

      assert(errs.product_type_id == ["the product type is not assignable"])
      assert(product == Products.get_product!(product.id))
    end

    test "delete_product/1 deletes a product with no paid orders of it",
         %{product: product} do
      order = order_fixture()
      suborder = suborder_fixture(%{order: order, product: product})

      {:ok, %Product{}} =
        product.id
        |> Products.get_product_with_order_count!()
        |> Products.delete_product()

      assert_raise(Ecto.NoResultsError, fn ->
        Products.get_product!(product.id)
      end)

      # Also deletes sub-orders containing the product.
      assert_raise(Ecto.NoResultsError, fn ->
        Orders.get_suborder!(suborder.id)
      end)
    end

    test "delete_product/1 does not delete a product with paid orders of it",
         %{product: product} do
      user = user_fixture()
      order = order_fixture(%{user: user})

      suborder =
        %{order: order, product: product}
        |> suborder_fixture()
        |> Map.replace!(:subtotal, nil)

      set_as_paid(order, user)

      {:error, %Changeset{} = set} =
        product.id
        |> Products.get_product_with_order_count!()
        |> Products.delete_product()

      assert(errors_on(set).paid_orders == ["has paid orders of it"])
      assert(Products.get_product!(product.id) == product)
      assert(Orders.get_suborder!(suborder.id) == suborder)
    end

    test "change_product/1 returns a product changeset", %{product: product} do
      assert(%Changeset{} = Products.change_product(product))
    end
  end

  describe "product_types" do
    alias CloudDbUi.Products.ProductType

    import CloudDbUi.ProductsFixtures

    @valid_attrs %{name: "some name", description: "some desc"}
    @update_attrs %{name: "updated name", description: "updated desc"}
    @invalid_attrs %{name: nil}

    setup do: %{type: product_type_fixture()}

    test "list_product_types_with_product_count/0 returns product types",
         %{type: type} do
      product_fixture(%{product_type: type})

      {:ok, {types, %Meta{}}} =
        Products.list_product_types_with_product_count()

      assert(types == [Map.replace!(type, :products, 1)])
    end

    test "get_product_type_with_products!/1 returns the type with given ID",
         %{type: type} do
      product = product_fixture(%{product_type: type})
      type_new = Map.replace!(type, :products, [product])

      assert(Products.get_product_type_with_products!(type.id) == type_new)
    end

    test "create_product_type/1 with valid data creates a product_type" do
      {:ok, %ProductType{} = type} = Products.create_product_type(@valid_attrs)

      assert(type.name == "some name")
      assert(type.description == "some desc")
    end

    test "create_product_type/1 with a blank description nilifies it" do
      {:ok, %ProductType{} = type} =
        %{description: " "}
        |> Enum.into(@valid_attrs)
        |> Products.create_product_type()

      assert(type.description == nil)
    end

    test "create_product_type/1 with invalid data returns a changeset" do
      errs =
        @invalid_attrs
        |> Products.create_product_type()
        |> errors_on()

      assert(errs.name == ["can't be blank"])
    end

    test "create_product_type/1 with a taken name returns a changeset" do
      product_type_fixture(%{name: "Taken"})

      {:error, set} = Products.create_product_type(%{name: "Taken"})

      assert(errors_on(set).name == ["has already been taken"])

      {:error, set_lowercase} = Products.create_product_type(%{name: "taken"})

      assert(errors_on(set_lowercase).name == ["has already been taken"])

      {:error, set_uppercase} = Products.create_product_type(%{name: "TAKEN"})

      assert(errors_on(set_uppercase).name == ["has already been taken"])
    end

    test "update_product_type/2 with valid data updates the product_type",
         %{type: type} do
      {:ok, %ProductType{} = updated} =
        Products.update_product_type(type, @update_attrs)

      assert(updated.name == "updated name")
      assert(updated.description == "updated desc")
    end

    test "update_product_type/2 with a blank description nilifies it",
         %{type: type} do
      {:ok, %ProductType{} = updated} =
        Products.update_product_type(
          type,
          Enum.into(%{description: " "}, @update_attrs)
        )

      assert(updated.description == nil)

      {:ok, %ProductType{} = with_blank_desc} =
        update_bypassing_context(product_type_fixture(), %{description: " "})

      assert(with_blank_desc.description == " ")

      {:ok, %ProductType{} = with_nil_desc} =
        Products.update_product_type(with_blank_desc, %{})

      assert(with_nil_desc.description == nil)
    end

    test "update_product_type/2 with invalid data returns an error changeset",
         %{type: type} do
      errs =
        type
        |> Products.update_product_type(@invalid_attrs)
        |> errors_on()

      assert(errs.name == ["can't be blank"])

      product = product_fixture(%{product_type: type})
      type_new = Map.replace!(type, :products, [product])

      assert(type_new == Products.get_product_type_with_products!(type.id))
    end

    test "update_product_type/2 with a taken name returns a changeset",
         %{type: type} do
      product_type_fixture(%{name: "Taken"})

      {:error, set} = Products.update_product_type(type, %{name: "Taken"})

      assert(errors_on(set).name == ["has already been taken"])

      {:error, set_lowercase} =
        Products.update_product_type(type, %{name: "taken"})

      assert(errors_on(set_lowercase).name == ["has already been taken"])

      {:error, set_uppercase} =
        Products.update_product_type(type, %{name: "TAKEN"})

      assert(errors_on(set_uppercase).name == ["has already been taken"])

      product = product_fixture(%{product_type: type})
      type_new = Map.replace!(type, :products, [product])

      assert(type_new == Products.get_product_type_with_products!(type.id))
    end

    test "delete_product_type/1 deletes a type not assigned to products" do
      type = product_type_fixture()

      {:ok, %ProductType{}} =
        type.id
        |> Products.get_product_type_with_product_count!()
        |> Products.delete_product_type()

      assert_raise(Ecto.NoResultsError, fn ->
        Products.get_product_type_with_products!(type.id)
      end)
    end

    test "delete_product_type/1 does not delete a type assigned to a product",
         %{type: type} do
      product = product_fixture(%{product_type: type})
      type_new = Map.replace!(type, :products, [product])

      {:error, %Changeset{} = set} =
        type.id
        |> Products.get_product_type_with_product_count!()
        |> Products.delete_product_type()

      assert(errors_on(set).products == ["has products"])
      assert(Products.get_product_type_with_products!(type.id) == type_new)
    end

    test "change_product_type/1 returns a changeset", %{type: type} do
      assert(%Changeset{} = Products.change_product_type(type))
    end
  end
end
