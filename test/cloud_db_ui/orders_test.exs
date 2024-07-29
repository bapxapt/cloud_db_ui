defmodule CloudDbUi.OrdersTest do
  use CloudDbUi.DataCase

  alias CloudDbUi.Orders
  alias Ecto.Changeset

  import CloudDbUi.{OrdersFixtures, AccountsFixtures, ProductsFixtures}

  describe "orders" do
    alias CloudDbUi.Orders.Order

    @invalid_attrs %{paid_at: ~U[2999-01-01T00:00:00+00], paid: true}

    # For Index as an administrator.
    test "list_orders_with_full_preloads/0 returns all orders with preloads" do
      user = user_fixture()
      prod = product_fixture()
      order = order_fixture(%{user_id: user.id})
      suborder = suborder_fixture(%{order_id: order.id, product_id: prod.id})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, prod),
          user
        )

      assert Orders.list_orders_with_full_preloads() == [order_new]
    end

    # For Index as a user.
    test "list_orders_with_preloaded_suborders/1 gets orders with preloads" do
      user = user_fixture()
      prod = product_fixture()
      order = order_fixture(%{user_id: user.id})
      suborder = suborder_fixture(%{order_id: order.id, product_id: prod.id})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, prod)
        )

      assert Orders.list_orders_with_suborder_products(user) == [order_new]
    end

    test "get_order_with_suborder_ids!/1 returns the order with a given ID" do
      order = order_fixture()
      suborder = suborder_fixture(%{order_id: order.id})
      order_new = Map.replace(order, :suborders, [suborder.id])

      assert Orders.get_order_with_suborder_ids!(order.id) == order_new
    end

    # For Show as an administrator.
    test "get_order_with_full_preloads!/1 returns an order with preloads" do
      user = user_fixture()
      prod = product_fixture()
      order = order_fixture(%{user_id: user.id})
      suborder = suborder_fixture(%{order_id: order.id, product_id: prod.id})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, prod),
          user
        )

      assert Orders.get_order_with_full_preloads!(order.id) == order_new
    end

    # For Show as a user.
    test "get_order_with_suborder_products!/2 returns an order w/ preloads" do
      owner = user_fixture()
      non_owner = user_fixture()
      prod = product_fixture()
      order = order_fixture(%{user_id: owner.id})
      suborder = suborder_fixture(%{order_id: order.id, product_id: prod.id})

      order_new =
        replace_order_fields(
          order,
          replace_suborder_fields(suborder, prod)
        )

      assert Orders.get_order_with_suborder_products!(order.id, owner) == order_new

      assert_raise Ecto.NoResultsError, fn ->
        Orders.get_order_with_suborder_products!(order.id, non_owner)
      end
    end

    test "create_order/1 with valid data creates an order" do
      user = user_fixture()

      valid_attrs = %{
        user_id: user.id,
        paid: true,
        paid_at: ~U[2020-01-01T00:00:00.000+00]
      }

      assert {:ok, %Order{} = order} = Orders.create_order(valid_attrs)
      assert order.user_id == user.id
      assert order.paid
      assert DateTime.compare(order.paid_at, ~U[2020-01-01T00:00:00.000+00]) == :eq
      assert order.total == Decimal.new("0.00")
    end

    test "create_order/1 with invalid data returns error changeset" do
      assert {:error, %Changeset{}} = Orders.create_order(@invalid_attrs)
    end

    test "update_order/3 with `:paid` and `:paid_at` updates the order" do
      owner = user_fixture()
      owner_new = user_fixture()
      order = order_fixture(%{user_id: owner.id})

      attrs = %{
        user_id: owner_new.id,
        paid: true,
        paid_at: ~U[2020-01-01T00:00:00.000+00]
      }

      assert {:ok, %Order{} = order} = Orders.update_order(order, attrs, owner_new)
      assert order.user_id == owner_new.id
      assert order.paid
      assert DateTime.compare(order.paid_at, ~U[2020-01-01T00:00:00.000+00]) == :eq
    end

    test "update_order/3 with `paid: false` sets `:paid_at` to `nil`" do
      owner = user_fixture()
      owner_new = user_fixture()
      order = order_paid_fixture(%{user_id: owner.id})

      attrs = %{
        user_id: owner_new.id,
        paid: false,
        paid_at: ~U[1990-10-10T00:00:00.000+00]
      }

      assert {:ok, %Order{} = order} = Orders.update_order(order, attrs, owner_new)
      assert order.user_id == owner_new.id
      assert order.paid == false
      assert order.paid_at == nil
    end

    test "update_order/3 w/ `paid: true` w/o `:paid_at` returns changeset" do
      owner = user_fixture()
      owner_new = user_fixture()
      order = order_fixture(%{user_id: owner.id})

      attrs = %{
        user_id: owner_new.id,
        paid: true
      }

      assert {:error, %Changeset{} = set} = Orders.update_order(order, attrs, owner_new)
      assert %{paid_at: ["can't be blank in a paid order"]} = errors_on(set)

      order_new = Map.replace(order, :suborders, [])

      assert Orders.get_order_with_suborder_ids!(order.id) == order_new
    end

    test "update_order/3 with invalid data returns error changeset" do
      user = user_fixture()
      order = order_fixture(%{user_id: user.id})

      assert {:error, %Changeset{}} = Orders.update_order(order, @invalid_attrs, user)

      order_new = Map.replace(order, :suborders, [])

      assert Orders.get_order_with_suborder_ids!(order.id) == order_new
    end

    test "delete_order/1 deletes the order" do
      order = order_fixture()

      assert {:ok, %Order{}} = Orders.delete_order(order)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_order_with_suborder_ids!(order.id) end
    end

    test "change_order/1 returns an order changeset" do
      order = order_fixture()

      assert %Changeset{} = Orders.change_order(order)
    end
  end

  describe "suborders" do
    alias CloudDbUi.Orders.SubOrder

    import CloudDbUi.OrdersFixtures

    @invalid_attrs %{quantity: nil, unit_price: nil}

    test "list_suborders_with_product_and_order_user/0 returns w/ preloads" do
      user = user_fixture()
      product = product_fixture()

      order =
        %{user_id: user.id}
        |> order_fixture()
        |> Map.replace!(:user, user)

      suborder =
        %{product_id: product.id, order_id: order.id}
        |> suborder_fixture()
        |> replace_suborder_fields(product)
        |> Map.replace!(:order, order)

      assert Orders.list_suborders_with_product_and_order_user() == [suborder]
    end

    test "get_suborder!/1 returns the suborder with given id" do
      suborder = suborder_fixture()

      assert Orders.get_suborder!(suborder.id) == suborder
    end

    test "create_suborder/1 with valid data creates a suborder" do
      product = product_fixture()
      order = order_paid_fixture()

      valid_attrs = %{
        quantity: 42,
        unit_price: 120.5,
        order_id: order.id,
        product_id: product.id
      }

      assert {:ok, %SubOrder{} = suborder} = Orders.create_suborder(valid_attrs)
      assert suborder.quantity == 42
      assert suborder.unit_price == Decimal.new("120.5")
    end

    test "create_suborder/1 with invalid data returns error changeset" do
      assert {:error, %Changeset{}} = Orders.create_suborder(@invalid_attrs)
    end

    test "update_suborder/2 with valid data updates the suborder" do
      prod = product_fixture()
      order = order_fixture()
      suborder = suborder_fixture(%{order_id: order.id, product_id: prod.id})
      attrs = %{quantity: 43, unit_price: Decimal.new("456.70")}

      assert {:ok, %SubOrder{} = suborder} = Orders.update_suborder(suborder, attrs, order, prod)
      assert suborder.quantity == 43
      assert suborder.unit_price == Decimal.new("456.70")
    end

    test "update_suborder/2 with invalid data returns error changeset" do
      prod = product_fixture()
      order = order_fixture()
      suborder = suborder_fixture(%{order_id: order.id, product_id: prod.id})

      assert {:error, %Changeset{}} = Orders.update_suborder(suborder, @invalid_attrs, order, prod)
      assert suborder == Orders.get_suborder!(suborder.id)
    end

    test "delete_suborder/1 deletes the suborder" do
      suborder = suborder_fixture()
      assert {:ok, %SubOrder{}} = Orders.delete_suborder(suborder)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_suborder!(suborder.id) end
    end

    test "change_suborder/1 returns a suborder changeset" do
      suborder = suborder_fixture()
      assert %Changeset{} = Orders.change_suborder(suborder)
    end
  end
end
