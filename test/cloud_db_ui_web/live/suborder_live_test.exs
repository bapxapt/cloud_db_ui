defmodule CloudDbUiWeb.SubOrderLiveTest do
  use CloudDbUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import CloudDbUi.OrdersFixtures

  @create_attrs %{quantity: 42, unit_price: 120.50}
  @update_attrs %{quantity: 4925, unit_price: 456.70}

  describe "Index, a not-logged-in guest" do
    setup [:create_suborder]

    test "gets redirected away", %{conn: conn, suborder: suborder} do
      assert_redirect_to_log_in_page(conn, ~p"/sub-orders")
      assert_redirect_to_log_in_page(conn, ~p"/sub-orders/new")
      assert_redirect_to_log_in_page(conn, ~p"/sub-orders/#{suborder}/edit")
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user, :create_suborder]

    test "gets redirected away", %{conn: conn, suborder: suborder} do
      assert_redirect_to_main_page(conn, ~p"/sub-orders")
      assert_redirect_to_main_page(conn, ~p"/sub-orders/new")
      assert_redirect_to_main_page(conn, ~p"/sub-orders/#{suborder}/edit")
    end
  end

  describe "Index, an admin" do
    setup [:create_paid_order_with_suborder, :register_and_log_in_admin]

    test "lists all sub-orders", %{conn: conn, suborder_paid: suborder} do
      other = suborder_fixture(%{unit_price: 10.01, quantity: 50})

      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      assert(page_title(index_live) =~ "Listing order positions")
      assert(has_element?(index_live, "#suborders-#{suborder.id}"))
      assert(has_element?(index_live, "#suborders-#{other.id}"))
      assert(has_table_cell?(index_live, "#{other.subtotal}"))
      assert(has_table_cell?(index_live, "#{suborder.subtotal}"))
    end

    test "saves a new sub-order", %{conn: conn} do
      suborder = suborder_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      refute(has_element?(index_live, "input#sub_order_order_id"))

      click(index_live, "div.flex-none > a", "New order position")

      assert(has_element?(index_live, "input#sub_order_order_id"))
      assert_patch(index_live, ~p"/sub-orders/new")
      assert_suborder_form_errors(index_live, suborder)

      # TODO: assert_suborder_form_changes(index_live, suborder)

      assert_suborder_subtotal_change(index_live, suborder)
      assert_suborder_order_id_label_change(index_live, suborder)
      assert_suborder_product_id_label_change(index_live, suborder)
      assert_suborder_unit_price_label_change(index_live, suborder)

      submit(index_live, "#suborder-form", %{sub_order: @create_attrs})

      assert_patch(index_live, ~p"/sub-orders")
      assert(has_flash?(index_live, :info, "Order position created"))
      assert(has_table_cell?(index_live, "5061.00"))
    end

    test "updates a sub-order of an unpaid order in listing", %{conn: conn} do
      suborder = suborder_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      index_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position ID #{suborder.id}")

      assert_patch(index_live, ~p"/sub-orders/#{suborder}/edit")
      assert_suborder_form_errors(index_live, suborder)

      # TODO: assert_suborder_form_changes(index_live, suborder)

      assert_suborder_subtotal_change(index_live, suborder)
      assert_suborder_order_id_label_change(index_live, suborder)
      assert_suborder_product_id_label_change(index_live, suborder)
      assert_suborder_unit_price_label_change(index_live, suborder)

      submit(index_live, "#suborder-form", %{sub_order: @update_attrs})

      assert_patch(index_live, ~p"/sub-orders")
      assert(has_flash?(index_live, :info, "sition ID #{suborder.id} updated"))

      index_live
      |> has_table_row?("#suborders-#{suborder.id}", ["4925", "456.70"])
      |> assert()
    end

    test "cannot update a sub-order of a paid order in listing",
         %{conn: conn, suborder_paid: suborder} do
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      index_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> refute_match("Edit order position ID #{suborder.id}")

      assert(has_flash?(index_live, "Cannot edit a position of a paid"))
    end

    test "deletes a sub-order of an unpaid order in listing", %{conn: conn} do
      deletable = suborder_fixture()
      {:ok, live, _html} = live(conn, ~p"/sub-orders")

      # TODO: assert_table_row_count(live, )

      click(live, "#suborders-#{deletable.id} a", "Delete")

      assert(has_flash?(live, :info, "eted order position ID #{deletable.id}"))
      refute(has_element?(live, "#suborders-#{deletable.id}"))
      # TODO: assert_table_row_count(live, )
    end

    test "cannot delete a sub-order of a paid order in listing",
         %{conn: conn, suborder_paid: suborder} do
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      # TODO: assert_table_row_count(live, )

      click(index_live, "#suborders-#{suborder.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete a position of a paid"))
      assert(has_element?(index_live, "#suborders-#{suborder.id}"))
      # TODO: assert_table_row_count(live, )
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_suborder]

    test "gets redirected away", %{conn: conn, suborder: suborder} do
      assert_redirect_to_log_in_page(conn, ~p"/sub-orders/#{suborder}")
      assert_redirect_to_log_in_page(conn, ~p"/sub-orders/#{suborder}/show")

      assert_redirect_to_log_in_page(
        conn,
        ~p"/sub-orders/#{suborder}/show/edit"
      )
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_suborder]

    test "gets redirected away", %{conn: conn, suborder: suborder} do
      assert_redirect_to_main_page(conn, ~p"/sub-orders/#{suborder}")
      assert_redirect_to_main_page(conn, ~p"/sub-orders/#{suborder}/show")
      assert_redirect_to_main_page(conn, ~p"/sub-orders/#{suborder}/show/edit")
    end
  end

  describe "Show, an admin" do
    setup [:create_paid_order_with_suborder, :register_and_log_in_admin]

    test "displays a sub-order of a paid order",
         %{conn: conn, suborder_paid: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      assert(page_title(show_live) =~ "Show order position ID #{suborder.id}")

      show_live
      |> list_item_title("Payment date and")
      |> assert_match("Payment date and time (UTC)")
    end

    test "updates a sub-order of an unpaid order within modal",
         %{conn: conn} do
      suborder = suborder_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit order position ID #{suborder.id}")

      assert_patch(show_live, ~p"/sub-orders/#{suborder}/show/edit")
      assert_suborder_form_errors(show_live, suborder_fixture())
      assert_suborder_subtotal_change(show_live, suborder)
      assert_suborder_order_id_label_change(show_live, suborder_fixture())
      assert_suborder_product_id_label_change(show_live, suborder_fixture())
      assert_suborder_unit_price_label_change(show_live, suborder)

      submit(show_live, "#suborder-form", %{sub_order: @update_attrs})

      assert_patch(show_live, ~p"/sub-orders/#{suborder}")
      assert(has_flash?(show_live, :info, "osition ID #{suborder.id} updated"))

      assert(list_item_value(show_live, "Quantity") == "4925")
      assert(list_item_value(show_live, "Unit price at") =~ "PLN 456.70 (high")
      assert(list_item_value(show_live, "Subtotal") == "PLN 2249247.50")
    end

    test "cannot update a sub-order of a paid order within modal",
         %{conn: conn, suborder_paid: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> refute_match("Edit order position ID #{suborder.id}")

      assert(has_flash?(show_live, "Cannot edit a position of a paid"))
    end

    test "deletes a sub-order of an unpaid order", %{conn: conn} do
      suborder = suborder_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn, ~p"/sub-orders")

      index_live
      |> has_flash?(:info, "Deleted order position ID #{suborder.id}")
      |> assert()

      refute(has_element?(index_live, "#suborders-#{suborder.id}"))
    end

    test "cannot delete a sub-order of a paid order",
         %{conn: conn, suborder_paid: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_flash?(show_live, "Cannot delete a position of a paid"))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end
  end
end
