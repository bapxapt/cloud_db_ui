defmodule CloudDbUiWeb.OrderLiveTest do
  use CloudDbUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import CloudDbUi.OrdersFixtures

  @create_attrs %{quantity: 42, total: 120.5}
  @update_attrs %{quantity: 43, total: 456.7}
  @invalid_attrs %{quantity: nil, total: nil}

  describe "Index (not logged in)" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert({:error, redirect} = live(conn, ~p"/orders"))
      assert({:redirect, %{to: path, flash: flash}} = redirect)
      assert(path == ~p"/users/log_in")
      assert(%{"error" => "You must log in to access this page."} = flash)
    end
  end

  describe "Index (user, unpaid order)" do
    setup [:register_and_log_in_user, :create_order]

    # Can see only own orders.
    test "lists only own orders", %{conn: conn, order: order} do
      order_by_other = order_fixture()
      {:ok, index_live, html} = live(conn, ~p"/orders")

      assert(html =~ "Listing orders")
      assert(has_element?(index_live, "#orders-#{order.id}"))
      refute(has_element?(index_live, "#orders-#{order_by_other.id}"))
    end

    test "updates an unpaid order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> element("#orders-#{order.id} a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit order")
      |> assert()

      assert_patch(index_live, ~p"/orders/#{order}/edit")

      index_live
      |> form("#order-form", order: %{quantity: nil})
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#order-form", order: %{quantity: 43})
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/orders")
      assert(render(index_live) =~ "Order updated successfully")
    end

    test "deletes an order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> element("#orders-#{order.id} a", "Delete")
      |> render_click()
      |> assert()

      refute(has_element?(index_live, "#orders-#{order.id}"))
    end
  end

  describe "Index (admin, unpaid order)" do
    setup [:create_order, :register_and_log_in_admin]

    # Can see orders of other users.
    test "lists all orders", %{conn: conn, order: order} do
      {:ok, index_live, html} = live(conn, ~p"/orders")

      assert(html =~ "Listing orders")
      assert(has_element?(index_live, "#orders-#{order.id}"))
    end

    # Can create orders manually.
    test "saves a new unpaid order", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> element("a", "New order")
      |> render_click()
      |> Kernel.=~("New order")
      |> assert()

      assert_patch(index_live, ~p"/orders/new")

      index_live
      |> form("#order-form", order: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#order-form", order: @create_attrs)
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/orders")
      assert(render(index_live) =~ "Order created successfully")
    end

    test "updates an order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> element("#orders-#{order.id} a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit order")
      |> assert()

      assert_patch(index_live, ~p"/orders/#{order}/edit")

      index_live
      |> form("#order-form", order: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#order-form", order: @update_attrs)
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/orders")
      assert(render(index_live) =~ "Order updated successfully")
    end

    test "deletes an order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> element("#orders-#{order.id} a", "Delete")
      |> render_click()
      |> assert()

      refute(has_element?(index_live, "#orders-#{order.id}"))
    end
  end

  describe "Index (user, paid order)" do
    setup [:register_and_log_in_user, :create_order_paid]

    test "cannot pay again for a paid order in listing",
         %{conn: conn, order: order} do
      # TODO: should not be able to pay for a paid order
    end

    test "cannot update a paid order in listing",
         %{conn: conn, order: order} do
      # TODO: should not be able to edit a paid order
    end

    test "cannot delete a paid order in listing",
         %{conn: conn, order: order} do
      # TODO: should not be able to delete a paid order
    end
  end

  describe "Index (admin, paid order)" do
    setup [:create_order_paid, :register_and_log_in_admin]

    test "updates a paid order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> element("#orders-#{order.id} a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit order")
      |> assert()

      assert_patch(index_live, ~p"/orders/#{order}/edit")

      index_live
      |> form("#order-form", order: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#order-form", order: @update_attrs)
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/orders")
      assert(render(index_live) =~ "Order updated successfully")
    end

    test "turns a paid order into an unpaid one in listing",
         %{conn: conn, order: order} do
      # TODO:
    end

    test "cannot delete a paid order in listing",
         %{conn: conn, order: order} do
      # TODO: should not be able to delete a paid order
    end
  end

  describe "Show (not logged in)" do
    setup [:create_order]

    test "redirects if user is not logged in", %{conn: conn, order: order} do
      assert({:error, redirect} = live(conn, ~p"/orders/#{order}"))
      assert({:redirect, %{to: path, flash: flash}} = redirect)
      assert(path == ~p"/users/log_in")
      assert(%{"error" => "You must log in to access this page."} = flash)
    end
  end

  describe "Show (user, unpaid order)" do
    setup [:register_and_log_in_user, :create_order]

    test "displays an order", %{conn: conn, order: order} do
      {:ok, _show_live, html} = live(conn, ~p"/orders/#{order}")

      assert(html =~ "Show order")
    end

    test "updates an order within modal", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> element("a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit order")
      |> assert()

      assert_patch(show_live, ~p"/orders/#{order}/show/edit")

      show_live
      |> form("#order-form", order: %{quantity: nil})
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      show_live
      |> form("#order-form", order: %{quantity: 43})
      |> render_submit()
      |> assert()

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(render(show_live) =~ "Order updated successfully")
    end

    test "pays for an order", %{conn: conn, order: order} do
      # TODO:
    end

    test "deletes an order", %{conn: conn, order: order} do
      # TODO:
    end
  end

  describe "Show (admin, unpaid order)" do
    setup [:register_and_log_in_admin, :create_order]

    test "displays an order", %{conn: conn, order: order} do
      {:ok, _show_live, html} = live(conn, ~p"/orders/#{order}")

      assert(html =~ "Show order")
      # TODO: admin-specific fields
    end

    test "updates an order within modal", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> element("a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit order")
      |> assert()

      assert_patch(show_live, ~p"/orders/#{order}/show/edit")

      show_live
      |> form("#order-form", order: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      show_live
      |> form("#order-form", order: @update_attrs)
      |> render_submit()
      |> assert()

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(render(show_live) =~ "Order updated successfully")
    end

    test "turns a unpaid order into a paid one within modal",
         %{conn: conn, order: order} do
      # TODO:
    end

    test "deletes an order", %{conn: conn, order: order} do
      # TODO:
    end
  end

  describe "Show (user, paid order)" do
    setup [:register_and_log_in_user, :create_order_paid]

    test "cannot update an order within modal", %{conn: conn, order: order} do
      # TODO: should not be able to edit a paid order
    end

    test "cannot delete an order", %{conn: conn, order: order} do
      # TODO: should not be able to delete a paid order
    end
  end

  describe "Show (admin, paid order)" do
    setup [:create_order_paid, :register_and_log_in_admin]

    test "updates an order within modal", %{conn: conn, order: order} do
      # TODO: should be able to edit a paid order
    end

    test "cannot delete an order", %{conn: conn, order: order} do
      # TODO: should not be able to delete a paid order
    end
  end

  defp create_order(%{user: user}) do
    %{order: order_fixture(%{user_id: user.id})}
  end

  defp create_order(_context), do: %{order: order_fixture()}

  defp create_order_paid(%{user: user}) do
    %{order: order_fixture(%{user_id: user.id, paid: true})}
  end

  defp create_order_paid(_context), do: %{order: order_fixture(%{paid: true})}
end
