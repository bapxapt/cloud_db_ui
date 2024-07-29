defmodule CloudDbUiWeb.OrderLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUi.Orders.Order
  alias Phoenix.LiveViewTest.View
  alias Plug.Conn

  import Phoenix.LiveViewTest
  import CloudDbUi.{AccountsFixtures, OrdersFixtures}

  @type html_or_redirect() :: CloudDbUi.Type.html_or_redirect()

  @update_attrs %{paid_at: ~U[1990-01-01 00:00:00Z], paid: true}

  # TODO: filter/sort/pagination tests

  describe "Index, a not-logged-in guest" do
    setup [:create_order]

    test "gets redirected away", %{conn: conn, order: order} do
      assert_redirect_to_log_in_page(live(conn, ~p"/orders"))
      assert_redirect_to_log_in_page(live(conn, ~p"/orders/new"))
      assert_redirect_to_log_in_page(live(conn, ~p"/orders/#{order}/edit"))
    end
  end

  describe "Index, a user" do
    setup [
      :register_and_log_in_user,
      :create_order,
      :create_paid_order_with_suborder
    ]

    test "gets redirected away when creating or editing orders",
         %{conn: conn, order: order} do
      assert_redirect_to_main_page(live(conn, ~p"/orders/new"))
      assert_redirect_to_main_page(live(conn, ~p"/orders/#{order}/edit"))
    end

    # Can see only own orders.
    test "lists only own orders", %{conn: conn, order: order} do
      other_user_order = order_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      assert(page_title(index_live) =~ "Listing orders")
      assert(has_element?(index_live, "#orders-#{order.id}"))
      refute(has_element?(index_live, "#orders-#{other_user_order.id}"))
    end

    test "cannot update an unpaid order in listing",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Edit")

      assert(has_flash?(index_live, "Only an administrator may"))
    end

    test "pays for an unpaid order", %{conn: conn, user: self, order: order} do
      CloudDbUi.Accounts.update_user(self, %{balance: 6000})
      suborder_fixture(%{order: order, unit_price: 0.01})

      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Pay")
      submit(index_live, "#form-order-payment")

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "Successfully paid for the"))
    end

    test "cannot pay for an unpaid order with insufficient balance",
         %{conn: conn, order: order} do
      suborder_fixture(%{order: order, quantity: 9001})

      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Pay")

      index_live
      |> has_form_error?("#form-order-payment", "insufficient funds")
      |> assert()

      submit(index_live, "#form-order-payment")

      assert_patch(index_live, ~p"/orders/#{order}/pay")
      assert(has_flash?(index_live, "Insufficient funds."))
    end

    test "cannot pay for an unpaid order that has no sub-orders",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Pay")

      index_live
      |> has_form_error?("#form-order-payment", "no order positions")
      |> assert()

      submit(index_live, "#form-order-payment")

      assert_patch(index_live, ~p"/orders/#{order}/pay")
      assert(has_flash?(index_live, "No order positions."))
    end

    test "deletes an unpaid order in listing", %{conn: conn, order: order} do
      user_admin_deletes_an_unpaid_order_in_listing(conn, order)
    end

    test "cannot pay again for a paid order in listing",
         %{conn: conn, order_paid: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Pay")

      assert(has_flash?(index_live, "Cannot pay again for a paid"))
    end

    test "cannot update a paid order in listing",
         %{conn: conn, order_paid: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Edit")

      assert(has_flash?(index_live, "Only an administrator may"))
    end

    test "cannot delete a paid order in listing",
         %{conn: conn, order_paid: order} do
      user_admin_cannot_delete_a_paid_order_in_listing(conn, order)
    end
  end

  describe "Index, an admin" do
    setup [
      :create_paid_order_with_suborder,
      :create_order,
      :register_and_log_in_admin
    ]

    test "lists all orders", %{conn: conn, order: order, user: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      assert(admin.id != order.user_id)
      assert(page_title(index_live) =~ "Listing orders")
      assert(has_element?(index_live, "th", "User ID"))
      assert(has_element?(index_live, "th", "User e-mail"))
      assert(has_element?(index_live, "#orders-#{order.id}"))
    end

    test "saves a new unpaid order", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      refute(has_element?(index_live, "input#order_user_id"))

      click(index_live, "div.flex-none > a", "New order")

      assert_patch(index_live, ~p"/orders/new")
      assert_table_row_count(index_live, 2)
      refute(checked?(index_live, :paid))
      assert_order_form_errors(index_live)
      assert_user_id_label_change(index_live)

      submit(index_live, "#order-form", %{order: %{paid: false}})

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "Order created successfully"))
      assert_table_row_count(index_live, 3)
    end

    test "updates an unpaid order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> click("#orders-#{order.id} a", "Edit")
      |> assert_match("Edit order ID")

      assert_patch(index_live, ~p"/orders/#{order}/edit")
      refute(checked?(index_live, :paid))
      assert_order_form_errors(index_live)
      assert_user_id_label_change(index_live)
      assert(checked?(index_live, :paid))

      submit(index_live, "#order-form")

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "#{order.id} updated successfully"))
    end

    test "deletes an unpaid order in listing", %{conn: conn, order: order} do
      user_admin_deletes_an_unpaid_order_in_listing(conn, order)
    end

    test "updates a paid order in listing", %{conn: conn, order_paid: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> click("#orders-#{order.id} a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      assert_patch(index_live, ~p"/orders/#{order}/edit")
      assert(checked?(index_live, :paid))
      assert_order_form_errors(index_live)
      assert_user_id_label_change(index_live)

      submit(index_live, "#order-form")

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "#{order.id} updated successfully"))
    end

    test "turns a paid order into an unpaid one in listing",
         %{conn: conn, order_paid: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> click("#orders-#{order.id} a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      assert_patch(index_live, ~p"/orders/#{order}/edit")
      # A current value of the "Paid" check box.
      assert(checked?(index_live, :paid))

      submit(index_live, "#order-form", %{order: %{paid: false}})

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "#{order.id} updated successfully"))
    end

    test "cannot delete a paid order in listing",
         %{conn: conn, order_paid: order} do
      user_admin_cannot_delete_a_paid_order_in_listing(conn, order)
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_order, :create_suborder]

    test "gets redirected away", %{conn: conn, order: order, suborder: sub} do
      assert_redirect_to_log_in_page(live(conn, ~p"/orders/#{order}"))
      assert_redirect_to_log_in_page(live(conn, ~p"/orders/#{order}/show"))

      conn
      |> live(~p"/orders/#{order}/show/edit")
      |> assert_redirect_to_log_in_page()

      conn
      |> live(~p"/orders/#{order}/show/#{sub}/edit")
      |> assert_redirect_to_log_in_page()
    end
  end

  describe "Show, a user" do
    setup [
      :register_and_log_in_user,
      :create_order,
      :create_suborder,
      :create_paid_order_with_suborder
    ]

    test "gets redirected away from editing",
         %{conn: conn, order: order, order_paid: paid} do
      assert_redirect_to_main_page(live(conn, ~p"/orders/#{order}/show/edit"))
      assert_redirect_to_main_page(live(conn, ~p"/orders/#{paid}/show/edit"))
    end

    test "displays an unpaid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(page_title(show_live) =~ "Show order ID #{order.id}")
      refute(has_list_item?(show_live, "User ID"))
      refute(has_list_item?(show_live, "User e-mail"))
    end

    test "cannot update an unpaid order within modal",
         %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Edit")

      assert(has_flash?(show_live, "Only an administrator may"))
    end

    test "pays for an unpaid order", %{conn: conn, user: self, order: order} do
      CloudDbUi.Accounts.update_user(self, %{balance: 6000})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Pay")
      submit(show_live, "#form-order-payment")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "Successfully paid for the"))
    end

    test "cannot pay for an unpaid order with insufficient balance",
         %{conn: conn, order: order} do
      suborder_fixture(%{order: order, quantity: 9001})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(click(show_live, "div.flex-none > a", "Pay") =~ "insufficient fu")

      submit(show_live, "#form-order-payment")

      assert_patch(show_live, ~p"/orders/#{order}/show/pay")
      assert(has_flash?(show_live, "Insufficient funds."))
    end

    test "cannot pay for an unpaid order that has no sub-orders",
         %{conn: conn, user: user} do
      without_suborders = order_fixture(%{user: user})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{without_suborders.id}")

      assert(click(show_live, "div.flex-none > a", "Pay") =~ "no order posit")

      submit(show_live, "#form-order-payment")

      assert_patch(show_live, ~p"/orders/#{without_suborders.id}/show/pay")
      assert(has_flash?(show_live, "No order positions."))
    end

    test "deletes an unpaid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn, ~p"/orders")

      assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}."))
      refute(has_element?(index_live, "#orders-#{order.id}"))
    end

    test "updates the quantity of a unpaid sub-order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(list_item_value(show_live, "Total") == "PLN 5061.00")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position")

      assert_patch(show_live, ~p"/orders/#{order}/show/#{suborder}/edit")
      assert_suborder_form_quantity_errors(show_live, suborder)
      assert_suborder_subtotal_change(show_live, suborder)

      submit(show_live, "#suborder-form", %{sub_order: %{quantity: 4925}})

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "Order position updated successful"))
      assert(list_item_value(show_live, "Total") == "PLN 593462.50")
      assert(has_table_cell?(show_live, "4925"))
    end

    test "cannot update an unpaid sub-order when the current price is higher",
         %{conn: conn, order: order} do
      suborder = suborder_fixture(%{order: order, unit_price: 0.01})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position")

      change_suborder_form(show_live, %{quantity: 43})

      show_live
      |> has_form_error?(
        "#suborder-form",
        :quantity,
        "current price of the product is PLN 120.50, cannot increase quantity"
      )
      |> assert()
    end

    test "deletes a last sub-order of an unpaid order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      {:ok, index_live, _html} =
        show_live
        |> click("#suborders-#{suborder.id} a", "Delete")
        |> follow_redirect(conn, ~p"/orders")

      assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}."))
      refute(has_element?(index_live, "#orders-#{order.id}"))
    end

    test "deletes a non-last sub-order of an unpaid order",
         %{conn: conn, order: order, suborder: suborder} do
      suborder_fixture(%{order: order, quantity: 100})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      # TODO: assert_table_row_count(show_live, 2)
      assert(list_item_value(show_live, "Total") == "PLN 17111.00")

      click(show_live, "#suborders-#{suborder.id} a", "Delete")

      refute(has_element?(show_live, "#suborders-#{suborder.id}"))
      assert(has_flash?(show_live, :info, "Deleted an order position."))
      assert(list_item_value(show_live, "Total") == "PLN 12050.00")
      # TODO: assert_table_row_count(show_live, 1)
    end

    test "displays a paid order", %{conn: conn, order_paid: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(page_title(show_live) =~ "Show order ID #{order.id}")
      refute(has_list_item?(show_live, "User ID"))
      refute(has_list_item?(show_live, "User e-mail"))
    end

    test "cannot update a paid order within modal",
         %{conn: conn, order_paid: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Edit")

      assert(has_flash?(show_live, "Only an administrator may"))
    end

    test "cannot pay again for a paid order",
         %{conn: conn, order_paid: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Pay")

      assert(has_flash?(show_live, "Cannot pay again for a paid"))
    end

    test "cannot delete a paid order", %{conn: conn, order_paid: order} do
      user_admin_cannot_delete_a_paid_order_in_show(conn, order)
    end

    test "cannot update quantity of a sub-order of a paid order",
         %{conn: conn, order_paid: order, suborder_paid: suborder} do
      user_admin_cannot_edit_a_suborder_of_a_paid_order(conn, order, suborder)
    end

    test "cannot delete a sub-order of a paid order",
         %{conn: conn, order_paid: order, suborder_paid: sub} do
      user_admin_cannot_delete_a_suborder_of_a_paid_order(conn, order, sub)
    end
  end

  describe "Show, an admin" do
    import CloudDbUi.{AccountsFixtures, ProductsFixtures}

    setup [
      :create_order,
      :create_suborder,
      :create_paid_order_with_suborder,
      :register_and_log_in_admin
    ]

    test "displays an unpaid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(page_title(show_live) =~ "Show order ID #{order.id}")
      assert(has_list_item?(show_live, "User ID"))
      assert(has_list_item?(show_live, "User e-mail"))
    end

    test "updates an unpaid order within modal", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      assert_patch(show_live, ~p"/orders/#{order}/show/edit")
      refute(checked?(show_live, :paid))
      assert_order_form_errors(show_live)
      assert_user_id_label_change(show_live)

      change_form(show_live, @update_attrs)
      submit(show_live, "#order-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "updated successfully"))
    end

    test "deletes an unpaid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn, ~p"/orders")

      assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}."))
      refute(has_element?(index_live, "#orders-#{order.id}"))
    end

    test "updates an unpaid sub-order without changing the order ID",
         %{conn: conn, order: order, suborder: suborder} do
      suborder_fixture(%{order: order, quantity: 100})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(list_item_value(show_live, "Total") == "PLN 17111.00")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position ID #{suborder.id}")

      assert_patch(show_live, ~p"/orders/#{order}/show/#{suborder}/edit")
      assert_suborder_form_errors(show_live, suborder)
      assert_suborder_subtotal_change(show_live, suborder)
      assert_suborder_order_id_label_change(show_live, suborder)
      assert_suborder_product_id_label_change(show_live, suborder)
      assert_suborder_unit_price_label_change(show_live, suborder)

      change_suborder_form(
        show_live,
        %{product_id: product_fixture().id, quantity: 4925, unit_price: 10.01}
      )

      submit(show_live, "#suborder-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "position ID #{suborder.id} updat"))
      assert(list_item_value(show_live, "Total") == "PLN 61349.25")
      assert(has_table_cell?(show_live, "4925"))
    end

    test "updates an unpaid sub-order while changing the order ID",
         %{conn: conn, order: order, suborder: suborder} do
      suborder_fixture(%{order: order, quantity: 100})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(list_item_value(show_live, "Total") == "PLN 17111.00")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position ID #{suborder.id}")

      assert_patch(show_live, ~p"/orders/#{order}/show/#{suborder}/edit")

      change_suborder_form(
        show_live,
        %{order_id: order_fixture().id, quantity: 4925, unit_price: 10.01}
      )

      submit(show_live, "#suborder-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "position ID #{suborder.id} updat"))
      assert(list_item_value(show_live, "Total") == "PLN 12050.00")
      # `:order_id` changed, the sub-order has been moved.
      refute(has_element?(show_live, "#suborders-#{suborder.id}"))
    end

    test "deletes a sub-order of an unpaid order",
         %{conn: conn, order: order, suborder: sub} do
      other = suborder_fixture(%{order: order, quantity: 100})
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      # TODO: assert_table_row_count(show_live, 2)
      assert(list_item_value(show_live, "Total") == "PLN 17111.00")

      click(show_live, "#suborders-#{other.id} a", "Delete")

      refute(has_element?(show_live, "#suborders-#{other.id}"))
      assert(has_flash?(show_live, :info, "ted order position ID #{other.id}"))
      assert(list_item_value(show_live, "Total") == "PLN 5061.00")
      # TODO: assert_table_row_count(show_live, 1)

      click(show_live, "#suborders-#{sub.id} a", "Delete")

      refute(has_element?(show_live, "#suborders-#{sub.id}"))
      assert(has_flash?(show_live, :info, "leted order position ID #{sub.id}"))
      assert(list_item_value(show_live, "Total") == "PLN 0.00")
      # TODO: assert_table_row_count(show_live, 0)
    end

    test "displays a paid order", %{conn: conn, order_paid: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(page_title(show_live) =~ "Show order ID #{order.id}")
      assert(has_list_item?(show_live, "User ID"))
      assert(has_list_item?(show_live, "User e-mail"))
    end

    test "updates a paid order within modal",
         %{conn: conn, order_paid: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      assert_patch(show_live, ~p"/orders/#{order}/show/edit")
      assert(checked?(show_live, :paid))
      assert_order_form_errors(show_live)
      assert_user_id_label_change(show_live)

      submit(show_live, "#order-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "Order ID #{order.id} updated"))
    end

    test "cannot pay for a paid order", %{conn: conn, order_paid: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Pay")

      assert(has_flash?(show_live, "Cannot pay for an order as an admin"))
    end

    test "cannot delete a paid order", %{conn: conn, order_paid: order} do
      user_admin_cannot_delete_a_paid_order_in_show(conn, order)
    end

    test "cannot edit a sub-order of a paid order",
         %{conn: conn, order_paid: order, suborder_paid: suborder} do
      user_admin_cannot_edit_a_suborder_of_a_paid_order(conn, order, suborder)
    end

    test "cannot delete a sub-order of a paid order",
         %{conn: conn, order_paid: order, suborder_paid: sub} do
      user_admin_cannot_delete_a_suborder_of_a_paid_order(conn, order, sub)
    end
  end

  @spec user_admin_deletes_an_unpaid_order_in_listing(%Conn{}, %Order{}) ::
            boolean()
  defp user_admin_deletes_an_unpaid_order_in_listing(%Conn{} = conn, order) do
    {:ok, index_live, _html} = live(conn, ~p"/orders")

    assert_table_row_count(index_live, 2)

    click(index_live, "#orders-#{order.id} a", "Delete")

    refute(has_element?(index_live, "#orders-#{order.id}"))
    assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}"))
    assert_table_row_count(index_live, 1)
  end

  @spec user_admin_cannot_delete_a_paid_order_in_listing(%Conn{}, %Order{}) ::
            boolean()
  defp user_admin_cannot_delete_a_paid_order_in_listing(conn, order) do
    {:ok, index_live, _html} = live(conn, ~p"/orders")

    assert_table_row_count(index_live, 2)

    click(index_live, "#orders-#{order.id} a", "Delete")

    assert(has_flash?(index_live, "Cannot delete a paid order."))
    assert_table_row_count(index_live, 2)
  end

  @spec user_admin_cannot_delete_a_paid_order_in_show(%Conn{}, %Order{}) ::
            boolean()
  defp user_admin_cannot_delete_a_paid_order_in_show(conn, order) do
    {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

    click(show_live, "div.flex-none > a", "Delete")

    assert(has_flash?(show_live, "Cannot delete a paid order."))
    assert(has_element?(show_live, "div.flex-none > a", "Delete"))
  end

  @spec user_admin_cannot_edit_a_suborder_of_a_paid_order(
          %Conn{},
          %Order{},
          %SubOrder{}
        ) :: boolean()
  defp user_admin_cannot_edit_a_suborder_of_a_paid_order(conn, order, sub) do
    {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

    click(show_live, "#suborders-#{sub.id} a", "Edit")

    assert(has_flash?(show_live, "Cannot edit a position of a paid"))
    assert(has_element?(show_live, "#suborders-#{sub.id} a", "Edit"))
  end

  @spec user_admin_cannot_delete_a_suborder_of_a_paid_order(
          %Conn{},
          %Order{},
          %SubOrder{}
        ) :: boolean()
  defp user_admin_cannot_delete_a_suborder_of_a_paid_order(conn, order, sub) do
    {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

    # TODO: assert_table_row_count(show_live, 1), but without the pagination counter

    click(show_live, "#suborders-#{sub.id} a", "Delete")

    assert(has_flash?(show_live, "Cannot delete a position of a paid"))
    assert(has_element?(show_live, "#suborders-#{sub.id} a", "Delete"))
    # TODO: assert_table_row_count(show_live, 1), but without the pagination counter
  end

  @spec assert_order_form_errors(%View{}) :: boolean()
  defp assert_order_form_errors(%View{} = live) do
    assert(form_errors(live, "#order-form") == [])
    assert_form_user_id_errors(live)

    change_form(live, %{paid: true})
    change_form(live, %{paid_at: nil})

    live
    |> has_form_error?("#order-form", :paid_at, "n&#39;t be blank in a paid")
    |> assert()

    assert_datetime_field_errors(live, "#order-form", :order, :paid_at)

    change_form(live, @update_attrs)

    assert(form_errors(live, "#order-form") == [])
  end

  @spec assert_form_user_id_errors(%View{}) :: boolean()
  defp assert_form_user_id_errors(%View{} = lv) do
    change_form(lv, %{user_id: nil})

    assert(has_form_error?(lv, "#order-form", :user_id, "can&#39;t be blank"))

    change_form(lv, %{user_id: "wrong@email.xyz"})

    assert(has_form_error?(lv, "#order-form", :user_id, "user not found"))

    change_form(
      lv,
      %{user_id: String.duplicate("a", 62) <> "@" <> String.duplicate("b", 99)}
    )

    assert(has_form_error?(lv, "#order-form", :user_id, "at most 160 charact"))

    change_form(lv, %{user_id: -1})

    assert(has_form_error?(lv, "#order-form", :user_id, "user not found"))

    change_form(lv, %{user_id: "_w"})

    assert(has_form_error?(lv, "#order-form", :user_id, "er an ID nor a valid e-"))
    assert_form_user_id_admin_errors(lv)

    change_form(lv, %{user_id: user_fixture().id})

    assert(form_errors(lv, "#order-form", :user_id) == [])
  end

  @spec assert_form_user_id_admin_errors(%View{}) :: boolean()
  defp assert_form_user_id_admin_errors(%View{} = lv) do
    admin = user_fixture(%{admin: true})

    change_form(lv, %{user_id: admin.id})

    lv
    |> has_form_error?("#order-form", :user_id, "ot assign an order to an adm")
    |> assert()

    change_form(lv, %{user_id: admin.email})

    lv
    |> has_form_error?("#order-form", :user_id, "ot assign an order to an adm")
    |> assert()

    assert(admin.email != String.upcase(admin.email))

    change_form(lv, %{user_id: String.upcase(admin.email)})

    lv
    |> has_form_error?("#order-form", :user_id, "ot assign an order to an adm")
    |> assert()
  end

  @spec assert_user_id_label_change(%View{}) :: boolean()
  defp assert_user_id_label_change(%View{} = live_view) do
    change_form(live_view, %{user_id: nil})

    assert(label_text(live_view, :user_id) == "User ID or e-mail address")

    other = user_fixture()

    change_form(live_view, %{user_id: other.id})

    live_view
    |> label_text(:user_id)
    |> assert_match("User ID (#{other.id}) or e-mail address (#{other.email})")
  end

  # Should return a rendered `#order-form`.
  @spec change_form(%View{}, %{atom() => any()}) :: html_or_redirect()
  defp change_form(%View{} = live_view, order_data) do
    change(live_view, "#order-form", %{order: order_data})
  end
end
