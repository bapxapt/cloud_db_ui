defmodule CloudDbUi.OrdersTest do
  use CloudDbUi.DataCase

  alias CloudDbUi.Orders
  import CloudDbUi.{AccountsFixtures, ProductsFixtures}

  describe "orders" do
    alias CloudDbUi.Orders.Order

    import CloudDbUi.OrdersFixtures

    @invalid_attrs %{paid_at: ~U[2999-01-01T00:00:00+00]}

    # TODO: check preloads
    test "list_orders_with_preloads/0 returns all orders with preloads" do
      order = order_fixture()

      assert Orders.list_orders_with_preloads() == [order]
    end

    # For Index as an administrator.
    test "list_orders_with_preloads/0 returns all orders with preloads" do
      user = user_fixture()
      product = product_fixture()

      order =
        %{user_id: user.id, product_id: product.id}
        |> order_fixture()
        |> Map.replace!(:user, user)
        |> Map.replace!(:product, product)

      assert Orders.list_orders_with_preloads() == [order]
    end

    # For Index as a user.
    test "list_orders_with_preloaded_suborders/1 gets orders with preloads" do
      user = user_fixture()
      suborder = suborder_fixture()

      order =
        %{user_id: user.id, product_id: product.id}
        |> order_fixture()
        |> Map.replace!(:suborders, [suborders])

      assert Orders.list_orders_with_preloaded_suborders(user) == [order]
    end

    # TODO: check preloads
    test "get_order_with_suborders!/1 returns the order with a given ID" do
      order = order_fixture()

      assert Orders.get_order_with_suborders!(order.id) == order
    end

    # For Show as an administrator.
    test "get_order_with_preloaded_user!/1 returns an order with preloads" do
      user = user_fixture()

      order =
        %{user_id: user.id, product_id: product.id}
        |> order_fixture()
        |> Map.replace!(:user, user)

      assert Orders.get_order_with_preloaded_user!(order.id) == order
    end

    test "create_order/1 with valid data creates an order" do
      user = user_fixture()
      product = product_fixture()

      valid_attrs = %{
        user_id: user.id,
        product_id: product.id,
        quantity: 42,
        total: 120.5
      }

      assert {:ok, %Order{} = order} = Orders.create_order(valid_attrs)
      assert order.quantity == 42
      assert order.total == 120.5
      assert order.user_id == user.id
      assert order.product_id == product.id
    end

    test "create_order/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Orders.create_order(@invalid_attrs)
    end

    test "update_order/2 with `:total` updates the order" do
      order = order_fixture()
      update_attrs = %{quantity: 43, total: 456.7}

      assert {:ok, %Order{} = order} = Orders.update_order(order, update_attrs)
      assert order.quantity == 43
      assert order.total == 456.7
    end

    test "update_order/2 without `:total` updates the order" do
      order = order_fixture()
      update_attrs = %{quantity: 43}

      assert {:ok, %Order{} = order} = Orders.update_order(order, update_attrs)
      assert order.quantity == 43
      assert order.total == 123.41
    end

    test "update_order/2 with invalid data returns error changeset" do
      order = order_fixture()

      assert {:error, %Ecto.Changeset{}} = Orders.update_order(order, @invalid_attrs)
      assert order == Orders.get_order_with_suborders!(order.id)
    end

    test "delete_order/1 deletes the order" do
      order = order_fixture()

      assert {:ok, %Order{}} = Orders.delete_order(order)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_order_with_suborders!(order.id) end
    end

    test "change_order/1 returns an order changeset" do
      order = order_fixture()

      assert %Ecto.Changeset{} = Orders.change_order(order)
    end
  end

  describe "suborders" do
    alias CloudDbUi.Orders.SubOrder

    import CloudDbUi.OrdersFixtures

    @invalid_attrs %{quantity: nil, unit_price: nil}

    test "list_suborders/0 returns all suborders with preloads" do
      product = product_fixture()

      suborder =
        %{product_id: product.id}
        |> suborder_fixture()
        |> Map.replace!(:product, product)

      assert Orders.list_suborders() == [suborder]
    end

    test "get_suborder!/1 returns the suborder with given id" do
      suborder = suborder_fixture()

      assert Orders.get_suborder!(suborder.id) == suborder
    end

    test "create_suborder/1 with valid data creates a suborder" do
      valid_attrs = %{quantity: 42, unit_price: 120.5}

      assert {:ok, %SubOrder{} = suborder} = Orders.create_suborder(valid_attrs)
      assert suborder.quantity == 42
      assert suborder.unit_price == 120.5
    end

    test "create_suborder/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Orders.create_suborder(@invalid_attrs)
    end

    test "update_suborder/2 with valid data updates the suborder" do
      suborder = suborder_fixture()
      update_attrs = %{quantity: 43, unit_price: 456.7}

      assert {:ok, %SubOrder{} = suborder} = Orders.update_suborder(suborder, update_attrs)
      assert suborder.quantity == 43
      assert suborder.unit_price == 456.7
    end

    test "update_suborder/2 with invalid data returns error changeset" do
      suborder = suborder_fixture()
      assert {:error, %Ecto.Changeset{}} = Orders.update_suborder(suborder, @invalid_attrs)
      assert suborder == Orders.get_suborder!(suborder.id)
    end

    test "delete_suborder/1 deletes the suborder" do
      suborder = suborder_fixture()
      assert {:ok, %SubOrder{}} = Orders.delete_suborder(suborder)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_suborder!(suborder.id) end
    end

    test "change_suborder/1 returns a suborder changeset" do
      suborder = suborder_fixture()
      assert %Ecto.Changeset{} = Orders.change_suborder(suborder)
    end
  end
end
