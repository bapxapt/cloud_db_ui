defmodule CloudDbUi.OrdersTest do
  use CloudDbUi.DataCase

  alias CloudDbUi.Orders
  alias Ecto.Changeset

  import CloudDbUi.{OrdersFixtures, AccountsFixtures, ProductsFixtures}

  describe "orders" do
    alias CloudDbUi.Orders.Order

    @valid_attrs %{paid_at: ~U[2020-01-01 00:00:00+00], paid: true}
    @invalid_attrs %{paid_at: ~U[2999-01-01 00:00:00+00], paid: true}

    setup do: %{owner: user_fixture()}

    # For Index as an administrator.
    test "list_orders_with_full_preloads/0 returns all orders with preloads",
         %{owner: owner} do
      product = product_fixture()
      order = order_fixture(%{user: owner})
      suborder = suborder_fixture(%{order: order, product: product})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, product),
          owner
        )

      assert(Orders.list_orders_with_full_preloads() == [order_new])
    end

    # For Index as a user.
    test "list_orders_with_preloaded_suborders/1 gets orders with preloads",
         %{owner: owner} do
      product = product_fixture()
      order = order_fixture(%{user: owner})
      suborder = suborder_fixture(%{order: order, product: product})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, product)
        )

      assert(Orders.list_orders_with_suborder_products(owner) == [order_new])
    end

    test "get_order_with_suborder_ids!/1 returns the order with a given ID" do
      order = order_fixture()
      suborder = suborder_fixture(%{order: order})
      order_new = Map.replace(order, :suborders, [suborder.id])

      assert(Orders.get_order_with_suborder_ids!(order.id) == order_new)
    end

    # For Show as an administrator.
    test "get_order_with_full_preloads!/1 returns an order with preloads",
         %{owner: owner} do
      product = product_fixture()
      order = order_fixture(%{user: owner})
      suborder = suborder_fixture(%{order: order, product: product})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, product),
          owner
        )

      assert(Orders.get_order_with_full_preloads!(order.id) == order_new)
    end

    # For Show as a user.
    test "get_order_with_suborder_products!/2 returns an order w/ preloads",
         %{owner: owner} do
      non_owner = user_fixture()
      product = product_fixture()
      order = order_fixture(%{user: owner})
      suborder = suborder_fixture(%{order: order, product: product})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, product)
        )

      order.id
      |> Orders.get_order_with_suborder_products!(owner)
      |> Kernel.==(order_new)
      |> assert()

      assert_raise(Ecto.NoResultsError, fn ->
        Orders.get_order_with_suborder_products!(order.id, non_owner)
      end)
    end

    test "create_order/2 with valid data creates an order", %{owner: owner} do
      {:ok, %Order{} = order} =
        @valid_attrs
        |> Enum.into(%{user_id: owner.id})
        |> Orders.create_order(owner)

      assert(order.user_id == owner.id)
      assert(order.paid)
      assert(DateTime.compare(order.paid_at, @valid_attrs.paid_at) == :eq)
      assert(order.total == Decimal.new("0.00"))
    end

    test "create_order/2 with invalid data returns a changeset",
         %{owner: owner} do
      errs =
        @invalid_attrs
        |> Orders.create_order(owner)
        |> errors_on()

      assert(errs.user_id == ["can't be blank"])
      assert(errs.paid_at == ["can't be in the future"])
    end

    test "create_order/2 with an admin ID (valid data) returns a changeset" do
      admin = user_fixture(%{admin: true})

      errs =
        @valid_attrs
        |> Enum.into(%{user_id: admin.id})
        |> Orders.create_order(admin)
        |> errors_on()

      assert(errs.user_id == ["cannot assign an order to an administrator"])
    end

    test "update_order/3 with `:paid` and `:paid_at` updates the order" do
      owner_new = user_fixture()

      {:ok, %Order{} = order} =
        Orders.update_order(
          order_fixture(),
          Enum.into(@valid_attrs, %{user_id: owner_new.id}),
          owner_new
        )

      assert(order.user_id == owner_new.id)
      assert(order.paid)
      assert(DateTime.compare(order.paid_at, @valid_attrs.paid_at) == :eq)
    end

    test "update_order/3 with `paid: false` sets `:paid_at` to `nil`" do
      owner_new = user_fixture()

      {:ok, %Order{} = order} =
        Orders.update_order(
          order_fixture(%{paid: true}),
          Enum.into(%{@valid_attrs | paid: false}, %{user_id: owner_new.id}),
          owner_new
        )

      assert(order.user_id == owner_new.id)
      assert(order.paid == false)
      assert(order.paid_at == nil)
    end

    test "update_order/3 w/ `paid: true` w/o `:paid_at` returns a changeset" do
      owner_new = user_fixture()

      {:error, %Changeset{} = set} =
        Orders.update_order(
          order_fixture(),
          %{user_id: owner_new.id, paid: true},
          owner_new
        )

      assert(errors_on(set).paid_at == ["can't be blank in a paid order"])
    end

    test "update_order/3 with invalid data returns a changeset",
         %{owner: owner} do
      order = order_fixture(%{user: owner})
      result = Orders.update_order(order, @invalid_attrs, owner)

      assert({:error, %Changeset{}} = result)
    end

    test "update_order/3 to have admin ID returns a changeset" do
      admin = user_fixture(%{admin: true})

      errs =
        Orders.update_order(
          order_fixture(),
          Enum.into(@valid_attrs, %{user_id: admin.id}),
          admin
        )
        |> errors_on()

      assert(errs.user_id == ["cannot assign an order to an administrator"])
    end

    test "pay_for_order/1 pays for an unpaid order" do
      paid =
        order_fixture()
        |> Orders.payment_changeset(%{paid: true})
        |> Orders.pay_for_order()
        |> elem(1)
        |> Map.replace!(:suborders, [])

      assert(Orders.get_order_with_suborder_ids!(paid.id) == paid)
    end

    test "pay_for_order/1 does not pay again for a paid order" do
      paid =
        %{paid: true}
        |> order_fixture()
        |> Map.replace!(:suborders, [])

      {:error, %Changeset{} = set} =
        paid
        |> Orders.payment_changeset(%{paid: true})
        |> Orders.pay_for_order()

      assert(errors_on(set).paid == ["the order has been paid for"])
      assert(Orders.get_order_with_suborder_ids!(paid.id) == paid)
    end

    test "delete_order/1 deletes an unpaid order" do
      order = order_fixture()
      {:ok, %Order{}} = Orders.delete_order(order)

      assert_raise(Ecto.NoResultsError, fn ->
        Orders.get_order_with_suborder_ids!(order.id)
      end)
    end

    test "delete_order/1 does not delete a paid order" do
      paid =
        %{paid: true}
        |> order_fixture()
        |> Map.replace!(:suborders, [])

      {:error, %Changeset{} = set} = Orders.delete_order(paid)

      assert(errors_on(set).paid == ["the order has been paid for"])
      assert(Orders.get_order_with_suborder_ids!(paid.id) == paid)
    end

    test "change_order/1 returns an order changeset" do
      changeset =
        order_fixture()
        |> Orders.change_order()

      assert(%Changeset{} = changeset)
    end
  end

  describe "suborders" do
    alias CloudDbUi.Orders.SubOrder

    import CloudDbUi.OrdersFixtures

    @valid_attrs %{quantity: 42, unit_price: 120.5}
    @invalid_attrs %{quantity: nil, unit_price: nil}

    setup do: %{order: order_fixture(), product: product_fixture()}

    test "list_suborders_with_product_and_order_user/0 returns w/ preloads",
         %{product: product} do
      user = user_fixture()

      order =
        %{user: user}
        |> order_fixture()
        |> Map.replace!(:user, user)

      suborder =
        %{order: order, product: product}
        |> suborder_fixture()
        |> replace_suborder_fields(product)
        |> Map.replace!(:order, order)

      assert(Orders.list_suborders_with_product_and_order_user() == [suborder])
    end

    test "get_suborder!/1 returns a sub-order with the given ID" do
      suborder =
        suborder_fixture()
        |> Map.replace!(:subtotal, nil)

      assert(Orders.get_suborder!(suborder.id) == suborder)
    end

    test "create_suborder/3 with valid data creates a sub-order",
         %{order: order, product: product} do
      {:ok, %SubOrder{} = suborder} =
        @valid_attrs
        |> Enum.into(%{order_id: order.id, product_id: product.id})
        |> Orders.create_suborder(order, product)

      assert(suborder.quantity == 42)
      assert(suborder.unit_price == Decimal.new("120.50"))
    end

    test "create_suborder/3 with invalid data returns a changeset",
         %{order: order, product: product} do
      result = Orders.create_suborder(@invalid_attrs, order, product)

      assert({:error, %Changeset{}} = result)
    end

    test "create_suborder/3 of a paid order (valid data) returns a changeset",
         %{product: prod} do
      order_paid = order_fixture(%{paid: true})

      result =
        @valid_attrs
        |> Enum.into(%{order_id: order_paid.id, product_id: prod.id})
        |> Orders.create_suborder(order_paid, prod)

      assert({:error, %Changeset{}} = result)
    end

    test "create_suborder/3 of a non-orderable product returns a changeset",
         %{order: order} do
      non_orderable = product_fixture(%{orderable: false})

      errs =
        @valid_attrs
        |> Enum.into(%{order_id: order.id, product_id: non_orderable.id})
        |> Orders.create_suborder(order, non_orderable)
        |> errors_on()

      assert(errs.product_id == ["cannot assign a non-orderable product"])
    end

    test "update_suborder/4 with valid data updates the suborder",
         %{order: order, product: product} do
      suborder = suborder_fixture(%{order: order, product: product})

      {:ok, %SubOrder{} = suborder_new} =
        Orders.update_suborder(
          suborder,
          %{quantity: 43, unit_price: 456.7},
          order,
          product
        )

      assert(suborder_new.quantity == 43)
      assert(suborder_new.unit_price == Decimal.new("456.70"))
    end

    test "update_suborder/4 with invalid data returns a changeset",
         %{order: order, product: product} do
      suborder = suborder_fixture(%{order: order, product: product})
      result = Orders.update_suborder(suborder, @invalid_attrs, order, product)

      assert({:error, %Changeset{}} = result)
    end

    test "update_suborder/4 with the ID of a paid order returns a changeset",
         %{order: order, product: prod} do
      suborder = suborder_fixture(%{order: order, product: prod})
      paid = order_fixture(%{paid: true})

      errs =
        Orders.update_suborder(
          suborder,
          Enum.into(@valid_attrs, %{order_id: paid.id, product_id: prod.id}),
          paid,
          prod
        )
        |> errors_on()

      assert(errs.order_id == ["the order has been paid for"])
    end

    test "update_suborder/4 to have a disabled product returns a changeset",
         %{order: ord, product: product} do
      suborder = suborder_fixture(%{order: ord, product: product})
      hidden = product_fixture(%{orderable: false})

      errs =
        Orders.update_suborder(
          suborder,
          Enum.into(@valid_attrs, %{order_id: ord.id, product_id: hidden.id}),
          ord,
          hidden
        )
        |> errors_on()

      assert(errs.product_id == ["cannot assign a non-orderable product"])
    end

    test "delete_suborder/2 deletes a sub-order of an unpaid order",
         %{order: order} do
      suborder = suborder_fixture(%{order: order})
      {:ok, %SubOrder{}} = Orders.delete_suborder(suborder, order)

      assert_raise(Ecto.NoResultsError, fn ->
        Orders.get_suborder!(suborder.id)
      end)
    end

    test "delete_suborder/2 does not delete a sub-order of a paid order" do
      owner = user_fixture()
      order = order_fixture(%{user: owner})

      suborder =
        %{order: order}
        |> suborder_fixture()
        |> Map.replace!(:subtotal, nil)

      {:error, %Changeset{} = set} =
        Orders.delete_suborder(suborder, set_as_paid(order, owner))

      assert(errors_on(set).order_id == ["the order has been paid for"])
      assert(Orders.get_suborder!(suborder.id) == suborder)
    end

    test "change_suborder/1 returns a sub-order changeset" do
      changeset =
        suborder_fixture()
        |> Orders.change_suborder()

      assert(%Changeset{} = changeset)
    end
  end
end
