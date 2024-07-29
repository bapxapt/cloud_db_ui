defmodule CloudDbUiWeb.OrderLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.Orders.SubOrder
  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest
  import CloudDbUi.OrdersFixtures

  @type redirect() :: CloudDbUi.Type.redirect()

  @update_attrs %{paid_at: ~U[1990-01-01T00:00:00.000+00], paid: true}

  describe "Index, a not-logged-in guest" do
    test "gets redirected away", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/orders")

      assert(path == ~p"/users/log_in")
      assert(flash["error"] =~ "You must log in to access this page.")
    end
  end

  describe "Index (unpaid order), a user" do
    setup [:register_and_log_in_user, :create_order]

    # Can see only own orders.
    test "lists only own orders", %{conn: conn, order: order} do
      other_user_order = order_fixture()
      {:ok, index_live, html} = live(conn, ~p"/orders")

      assert(html =~ "Listing orders")
      assert(has_element?(index_live, "#orders-#{order.id}"))
      refute(has_element?(index_live, "#orders-#{other_user_order.id}"))
    end

    test "cannot update an unpaid order in listing",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Edit")

      assert(has_flash?(index_live, "Only an administrator may"))
    end

    test "pays for an order", %{conn: conn, order: order} do
      suborder_fixture(%{order_id: order.id, unit_price: "0.01"})

      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Pay")
      submit(index_live, "#form-order-payment")

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "Successfully paid for the"))
    end

    test "cannot pay for an order with insufficient balance",
         %{conn: conn, order: order} do
      suborder_fixture(%{order_id: order.id, quantity: 9001})

      {:ok, index_live, _html} = live(conn, ~p"/orders")

      assert(click(index_live, "#orders-#{order.id} a", "Pay") =~ "insufficie")

      submit(index_live, "#form-order-payment")

      assert_patch(index_live, ~p"/orders/#{order}/pay")
      assert(has_flash?(index_live, "Insufficient funds."))
    end

    test "cannot pay for an order that has no sub-orders",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      assert(click(index_live, "#orders-#{order.id} a", "Pay") =~ "no order p")

      submit(index_live, "#form-order-payment")

      assert_patch(index_live, ~p"/orders/#{order}/pay")
      assert(has_flash?(index_live, "No order positions."))
    end

    test "deletes an order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Delete")

      refute(has_element?(index_live, "#orders-#{order.id}"))
      assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}"))
    end
  end

  describe "Index (unpaid order), an admin" do
    setup [:create_order, :register_and_log_in_admin]

    # Can see orders of other users.
    test "lists all orders", %{conn: conn, order: order, user: admin} do
      {:ok, index_live, html} = live(conn, ~p"/orders")

      assert(admin.id != order.user_id)
      assert(html =~ "Listing orders")
      assert(has_element?(index_live, "th", "User ID"))
      assert(has_element?(index_live, "th", "User e-mail"))
      assert(has_element?(index_live, "#orders-#{order.id}"))
    end

    # Can create orders manually.
    test "saves a new unpaid order", %{conn: conn, user: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      refute(has_element?(index_live, "input#order_user_id"))

      click(index_live, "div.flex-none > a", "New order")

      assert(has_element?(index_live, "input#order_user_id"))
      assert_patch(index_live, ~p"/orders/new")
      assert_order_form_errors(index_live, admin.email)
      assert_user_id_label_change(index_live)

      change(index_live, "#order-form", %{order: @update_attrs})
      submit(index_live, "#order-form")

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "Order created successfully"))
    end

    test "updates an order in listing",
         %{conn: conn, order: order, user: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> click("#orders-#{order.id} a", "Edit")
      |> assert_match("Edit order ID")

      assert_patch(index_live, ~p"/orders/#{order}/edit")
      assert_order_form_errors(index_live, admin.email)
      assert_user_id_label_change(index_live)

      change(index_live, "#order-form", %{order: @update_attrs})
      submit(index_live, "#order-form")

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "updated successfully"))
    end

    test "deletes an order in listing", %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Delete")

      refute(has_element?(index_live, "#orders-#{order.id}"))
      assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}"))
    end
  end

  describe "Index (paid order), a user" do
    setup [:register_and_log_in_user, :create_paid_order]

    test "cannot pay again for a paid order in listing",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Pay")

      assert(has_flash?(index_live, "Cannot pay again for a paid"))
    end

    test "cannot update a paid order in listing",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Edit")

      assert(has_flash?(index_live, "Only an administrator may"))
    end

    test "cannot delete a paid order in listing",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete a paid order."))
    end
  end

  describe "Index (paid order), an admin" do
    import CloudDbUi.AccountsFixtures

    setup [:create_paid_order, :register_and_log_in_admin]

    test "updates a paid order in listing",
         %{conn: conn, order: order, user: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      other_user = user_fixture()

      index_live
      |> click("#orders-#{order.id} a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      assert(has_element?(index_live, "input[type=checkbox][value=true]"))
      assert_patch(index_live, ~p"/orders/#{order}/edit")
      assert_order_form_errors(index_live, admin.email)
      assert_user_id_label_change(index_live)

      change(index_live, "#order-form", %{order: @update_attrs})
      submit(index_live, "#order-form")

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "updated successfully"))
    end

    test "turns a paid order into an unpaid one in listing",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      index_live
      |> click("#orders-#{order.id} a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      # A current value.
      assert(render(index_live, "input[type=checkbox]") =~ "value=\"true\"")
      assert_patch(index_live, ~p"/orders/#{order}/edit")

      submit(index_live, "#order-form", %{order: %{paid: false}})

      assert_patch(index_live, ~p"/orders")
      assert(has_flash?(index_live, :info, "updated successfully"))
    end

    test "cannot delete a paid order in listing",
         %{conn: conn, order: order} do
      {:ok, index_live, _html} = live(conn, ~p"/orders")

      click(index_live, "#orders-#{order.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete a paid order."))
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_order]

    test "gets redirected away", %{conn: conn, order: order} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/orders/#{order}")

      assert(path == ~p"/users/log_in")
      assert(flash["error"] =~ "You must log in to access this page.")
    end
  end

  describe "Show (unpaid order), a user" do
    setup [:register_and_log_in_user, :create_order, :create_suborder]

    test "displays an order", %{conn: conn, order: order} do
      {:ok, _show_live, html} = live(conn, ~p"/orders/#{order}")

      assert(html =~ "Show order")
      refute(html =~ "User ID")
      refute(html =~ "User e-mail")
    end

    test "cannot update an order within modal", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Edit")

      assert(has_flash?(show_live, "Only an administrator may"))
    end

    test "pays for an order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Pay")
      submit(show_live, "#form-order-payment")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "Successfully paid for the"))
    end

    test "cannot pay for an order with insufficient balance",
         %{conn: conn, order: order} do
      suborder_fixture(%{order_id: order.id, quantity: 9001})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      assert(click(show_live, "div.flex-none > a", "Pay") =~ "insufficient f")

      submit(show_live, "#form-order-payment")

      assert_patch(show_live, ~p"/orders/#{order}/show/pay")
      assert(has_flash?(show_live, "Insufficient funds."))
    end

    test "cannot pay for an order that has no sub-orders",
         %{conn: conn, user: user} do
      without_suborders = order_fixture(%{user_id: user.id})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{without_suborders.id}")

      assert(click(show_live, "div.flex-none > a", "Pay") =~ "no order posit")

      submit(show_live, "#form-order-payment")

      assert_patch(show_live, ~p"/orders/#{without_suborders.id}/show/pay")
      assert(has_flash?(show_live, "No order positions."))
    end

    test "deletes an order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Delete")

      flash = assert_redirect(show_live, ~p"/orders")

      assert(flash["info"] =~ "Deleted order ID #{order.id}.")

      {:ok, index_live, _html} = live(conn, ~p"/orders")

      refute(has_element?(index_live, "#orders-#{order.id}"))
    end

    test "updates the quantity of a sub-order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position")

      assert_patch(show_live, ~p"/orders/#{order}/show/#{suborder}/edit")
      # TODO: check total in the order before updating a sub-order

      show_live
      |> change_suborder_form(%{quantity: 0})
      |> assert_match("fewer than one piece")

      show_live
      |> change_suborder_form(%{quantity: SubOrder.quantity_limit() + 1})
      |> assert_match("cannot order more than #{SubOrder.quantity_limit()}")

      assert_suborder_subtotal_change(show_live, suborder)

      submit(show_live, "#suborder-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "Order position updated success"))
    end

    test "cannot update a sub-order when the current product price is higher",
         %{conn: conn, order: order} do
      suborder = suborder_fixture(%{order_id: order.id, unit_price: "0.01"})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position")

      show_live
      |> change_suborder_form(%{quantity: 99_999})
      |> assert_match("cannot increase quantity")
    end

    test "deletes a last sub-order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      {:ok, index_live, _html} =
        show_live
        |> click("#suborders-#{suborder.id} a", "Delete")
        |> follow_redirect(conn)

      assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}."))
      refute(has_element?(index_live, "#orders-#{order.id}"))
    end

    test "deletes a non-last sub-order",
         %{conn: conn, order: order, suborder: suborder} do
      suborder_fixture(%{order_id: order.id})

      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "#suborders-#{suborder.id} a", "Delete")

      refute(has_element?(show_live, "#suborders-#{suborder.id}"))
      assert(has_flash?(show_live, :info, "Deleted an order position."))
    end
  end

  describe "Show (unpaid order), an admin" do
    alias CloudDbUi.Orders.SubOrder
    alias CloudDbUi.Accounts.User

    import CloudDbUi.ProductsFixtures

    setup [:register_and_log_in_admin, :create_order, :create_suborder]

    test "displays an order", %{conn: conn, order: order} do
      {:ok, _show_live, html} = live(conn, ~p"/orders/#{order}")

      assert(html =~ "Show order")
      assert(html =~ "User ID")
    end

    test "updates an order within modal",
         %{conn: conn, order: order, user: admin} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      assert_patch(show_live, ~p"/orders/#{order}/show/edit")
      assert_order_form_errors(show_live, admin.email)
      assert_user_id_label_change(show_live)

      change(show_live, "#order-form", %{order: @update_attrs})
      submit(show_live, "#order-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "updated successfully"))
    end

    test "deletes an order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn)

      assert(has_flash?(index_live, :info, "Deleted order ID #{order.id}."))
      refute(has_element?(index_live, "#orders-#{order.id}"))
    end

    test "cannot update a sub-order with invalid data",
         %{conn: conn, order: order, suborder: suborder} do
      # TODO:
      assert false
    end

    test "updates a sub-order without changing the order ID",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position ID #{suborder.id}")

      assert_patch(show_live, ~p"/orders/#{order}/show/#{suborder}/edit")
      # TODO: check total in the order before updating a sub-order

      show_live
      |> change_suborder_form(%{order_id: nil})
      |> assert_match("can&#39;t be blank")

      show_live
      |> change_suborder_form(%{order_id: -order.id})
      |> assert_match("order not found")

      show_live
      |> change_suborder_form(%{order_id: order_paid_fixture().id})
      |> assert_match("cannot assign an order position to a paid order")

      show_live
      |> change_suborder_form(%{order_id: order.id, product_id: nil})
      |> assert_match("can&#39;t be blank")

      show_live
      |> change_suborder_form(%{product_id: -suborder.product_id})
      |> assert_match("product not found")

      show_live
      |> change_suborder_form(
        %{product_id: product_fixture(%{orderable: false}).id}
      )
      |> assert_match("cannot assign a non-orderable product")

      show_live
      |> change_suborder_form(
        %{product_id: product_fixture().id, unit_price: nil}
      )
      |> assert_match("can&#39;t be blank")

      show_live
      |> change_suborder_form(%{unit_price: "asdf"})
      |> assert_match("is invalid")

      show_live
      |> change_suborder_form(%{unit_price: -1})
      |> assert_match("must not be negative")

      show_live
      |> change_suborder_form(%{unit_price: "2.500"})
      |> assert_match("invalid format")

      show_live
      |> change_suborder_form(
        %{unit_price: Decimal.add(User.balance_limit(), "0.01")}
      )
      |> assert_match("must be less than or equal to #{User.balance_limit()}")

      show_live
      |> change_suborder_form(%{unit_price: 2, quantity: nil})
      |> assert_match("can&#39;t be blank")

      show_live
      |> change_suborder_form(%{quantity: SubOrder.quantity_limit() + 1})
      |> assert_match("cannot order more than #{SubOrder.quantity_limit()}")

      show_live
      |> change_suborder_form(%{quantity: 0})
      |> assert_match("fewer than one piece")

      assert_suborder_subtotal_change(show_live, suborder)

      change_suborder_form(
        show_live,
        %{product_id: suborder.product_id, quantity: 4925}
      )

      submit(show_live, "#suborder-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "position ID #{suborder.id} updat"))
      # TODO: check total in the order after updating a sub-order
      assert(render(show_live) =~ "4925")
    end

    test "updates a sub-order while changing the order ID",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> assert_match("Edit order position ID #{suborder.id}")

      assert_patch(show_live, ~p"/orders/#{order}/show/#{suborder}/edit")

      submit(
        show_live,
        "#suborder-form",
        %{sub_order: %{order_id: order_fixture().id}}
      )

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "position ID #{suborder.id} updat"))
      # `:order_id` changed, the sub-order has been moved.
      refute(has_element?(show_live, "#suborders-#{suborder.id}"))
    end

    test "deletes a sub-order", %{conn: conn, order: order, suborder: sub} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "#suborders-#{sub.id} a", "Delete")

      refute(has_element?(show_live, "#suborders-#{sub.id}"))
      assert(has_flash?(show_live, :info, "leted order position ID #{sub.id}"))
    end
  end

  describe "Show (paid order), a user" do
    setup [:register_and_log_in_user, :create_paid_order, :create_suborder]

    test "cannot update an order within modal", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Edit")

      assert(has_flash?(show_live, "Only an administrator may"))
    end

    test "cannot pay again for a paid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Pay")

      assert(has_flash?(show_live, "Cannot pay again for a paid"))
    end

    test "cannot delete a paid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_flash?(show_live, "Cannot delete a paid order."))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end

    test "cannot update quantity of a sub-order of a paid order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "#suborders-#{suborder.id} a", "Edit")

      assert(has_flash?(show_live, "Cannot edit a position of a paid"))
    end

    test "cannot delete a sub-order of a paid order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "#suborders-#{suborder.id} a", "Delete")

      assert(has_flash?(show_live, "Cannot delete a position of a paid"))
      assert(has_element?(show_live, "#suborders-#{suborder.id} a", "Delete"))
    end
  end

  describe "Show (paid order), an admin" do
    import CloudDbUi.AccountsFixtures

    setup [:register_and_log_in_admin, :create_paid_order, :create_suborder]

    test "updates a paid order within modal",
         %{conn: conn, order: order, user: admin} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit order ID #{order.id}")

      assert(has_element?(show_live, "input[type=checkbox][value=true]"))
      assert_patch(show_live, ~p"/orders/#{order}/show/edit")
      assert_order_form_errors(show_live, admin.email)
      assert_user_id_label_change(show_live)

      change(show_live, "#order-form", %{order: @update_attrs})
      submit(show_live, "#order-form")

      assert_patch(show_live, ~p"/orders/#{order}")
      assert(has_flash?(show_live, :info, "Order ID #{order.id} updated"))
    end

    test "cannot pay for a paid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Pay")

      assert(has_flash?(show_live, "Cannot pay for an order as an admin"))
    end

    test "cannot delete a paid order", %{conn: conn, order: order} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_flash?(show_live, "Cannot delete a paid order."))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end

    test "cannot edit a sub-order of a paid order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "#suborders-#{suborder.id} a", "Edit")

      assert(has_flash?(show_live, "Cannot edit a position of a paid"))
    end

    test "cannot delete a sub-order of a paid order",
         %{conn: conn, order: order, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/orders/#{order}")

      click(show_live, "#suborders-#{suborder.id} a", "Delete")

      assert(has_flash?(show_live, "Cannot delete a position of a paid"))
      assert(has_element?(show_live, "#suborders-#{suborder.id} a", "Delete"))
    end
  end

  @spec assert_order_form_errors(%View{}, any()) :: boolean()
  defp assert_order_form_errors(live, admin_id) do
    assert(change_user_id(live, nil) =~ "can&#39;t be blank")
    assert(change_user_id(live, "wrong@email.xyz") =~ "user not found")
    assert(change_user_id(live, "_w") =~ "neither an ID nor a valid e-mail")
    assert(change_user_id(live, admin_id) =~ "annot assign an order to an adm")

    change(live, "#order-form", %{order: %{paid: true}})

    live
    |> change("#order-form", %{order: %{paid_at: nil}})
    |> assert_match("can&#39;t be blank in a paid order")

    live
    |> change(
      "#order-form",
      %{order: %{paid_at: ~U[2999-01-01T00:00:00.000+00]}}
    )
    |> assert_match("can&#39;t be in the future")
  end

  @spec assert_user_id_label_change(%View{}) :: boolean()
  defp assert_user_id_label_change(live) do
    other = CloudDbUi.AccountsFixtures.user_fixture()

    live
    |> change_user_id(other.id)
    |> assert_match("ID (#{other.id}) or e-mail address (#{other.email})")
  end

  # Returns a rendered `#suborder-form`.
  @spec change_suborder_form(%View{}, %{atom() => any()}) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_suborder_form(%View{} = show_live, suborder_data) do
    change(show_live, "#suborder-form", %{sub_order: suborder_data})
  end

  # Returns a rendered `#order-form`.
  @spec change_form(%View{}, %{atom() => any()}) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_form(%View{} = live_view, order_data) do
    change(live_view, "#order-form", %{order: order_data})
  end

  @spec change_user_id(%View{}, any()) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_user_id(%View{} = live_view, user_id) do
    change(live_view, "#order-form", %{order: %{user_id: user_id}})
  end
end
