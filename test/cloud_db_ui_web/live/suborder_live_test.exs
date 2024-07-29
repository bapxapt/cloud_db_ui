defmodule CloudDbUiWeb.SubOrderLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.Orders.SubOrder
  alias Ecto.SubQueryError
  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest
  import CloudDbUi.{OrdersFixtures, ProductsFixtures}

  @type redirect() :: CloudDbUi.Type.redirect()

  @create_attrs %{quantity: 42, unit_price: "120.50"}
  @update_attrs %{quantity: 4925, unit_price: "456.70"}
  @invalid_attrs %{quantity: nil, unit_price: nil}

  describe "Index, a not-logged-in guest" do
    test "gets redirected away", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/sub-orders")

      assert(path == ~p"/users/log_in")
      assert(flash["error"] =~ "You must log in to access this page.")
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user]

    test "gets redirected away", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/sub-orders")

      assert(path == ~p"/")
      assert(flash["error"] =~ "Only an administrator may access")
    end
  end

  describe "Index, an admin" do
    setup [:register_and_log_in_admin, :create_paid_order, :create_suborder]

    test "lists all suborders", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/sub-orders")

      assert(html =~ "Listing order positions")
      # TODO: assert(html =~ "_____________")
    end

    test "saves a new sub-order", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      refute(has_element?(index_live, "input#sub_order_order_id"))

      click(index_live, "div.flex-none > a", "New order position")

      assert(has_element?(index_live, "input#sub_order_order_id"))
      assert_patch(index_live, ~p"/sub-orders/new")

      index_live
      |> form("#suborder-form", %{sub_order: @invalid_attrs})
      |> render_change() =~ "can&#39;t be blank"

      submit(index_live, "#suborder-form", %{sub_order: @create_attrs})

      assert_patch(index_live, ~p"/sub-orders")
      assert(has_flash?(index_live, :info, "Order position created"))
      # TODO: assert(render(index_live) =~ )
    end

    test "updates a sub-order of an unpaid order in listing",
         %{conn: conn, order: order_paid} do
      unpaid = suborder_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      index_live
      |> click("#suborders-#{unpaid.id} a", "Edit")
      |> assert_match("Edit order position ID #{unpaid.id}")

      assert_patch(index_live, ~p"/sub-orders/#{unpaid}/edit")
      assert(change_order_id(index_live, nil) =~ "can&#39;t be blank")
      assert(change_order_id(index_live, -unpaid.id) =~ "order not found")

      index_live
      |> change_order_id(order_paid.id)
      |> assert_match("cannot assign an order position to a paid order")

      refute(change_order_id(index_live, order_new.id) =~ "can&#39;t be blank")
      assert(change_product_id(index_live, nil) =~ "can&#39;t be blank")
      assert(change_product_id(index_live, -sub.product_id) =~ "uct not found")

      index_live
      |> change_product_id(non_orderable.id)
      |> assert_match("cannot assign a non-orderable product")

      index_live
      |> change_product_id(product_new.id)
      |> refute_match("can&#39;t be blank")

      assert(change_unit_price(index_live, nil) =~ "can&#39;t be blank")
      assert(change_unit_price(index_live, "ok") =~ "is invalid")
      assert(change_unit_price(index_live, -1) =~ "must not be negative")
      assert(change_unit_price(index_live, "2.500") =~ "invalid format")

      index_live
      |> change_unit_price(Decimal.add(User.balance_limit(), "0.01"))
      |> assert_match("must be less than or equal to #{User.balance_limit()}")

      index_live
      |> change_form(%{unit_price: "5.00", quantity: 0})
      |> assert_match("fewer than one piece")

      index_live
      |> change_form(%{quantity: SubOrder.quantity_limit() + 1})
      |> assert_match("cannot order more than #{SubOrder.quantity_limit()}")

      submit(index_live, "#suborder-form", %{sub_order: @update_attrs})

      assert_patch(index_live, ~p"/sub-orders")
      assert(has_flash?(index_live ,:info, "position ID #{unpaid.id} updat"))
      assert(render(index_live) =~ "4925")
    end

    test "cannot update a sub-order of a paid order in listing",
         %{conn: conn, suborder: suborder} do
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      index_live
      |> click("#suborders-#{suborder.id} a", "Edit")
      |> refute_match("Edit order position ID #{suborder.id}")

      assert(has_flash?(index_live, "Cannot edit a position of a paid"))
    end

    test "deletes a sub-order of an unpaid order in listing", %{conn: conn} do
      unpaid = suborder_fixture()
      {:ok, live, _html} = live(conn, ~p"/sub-orders")

      click("#suborders-#{unpaid.id} a", "Delete")

      refute(has_flash?(live, :info, "leted order position ID #{unpaid.id}"))
      refute(has_element?(live, "#suborders-#{unpaid.id}"))
    end

    test "cannot delete a sub-order of a paid order in listing",
         %{conn: conn, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_flash?(show_live, "Cannot delete a position of a paid"))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_suborder]

    test "gets redirected away", %{conn: conn, suborder: suborder} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/sub-orders/#{suborder}")

      assert(path == ~p"/users/log_in")
      assert(flash["error"] =~ "You must log in to access this page.")
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_suborder]

    test "gets redirected away", %{conn: conn, suborder: suborder} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/sub-orders/#{suborder}")

      assert(path == ~p"/")
      assert(flash["error"] =~ "Only an administrator may access")
    end
  end

  describe "Show, an admin" do
    setup [:register_and_log_in_admin, :create_paid_order, :create_suborder]

    test "displays a sub-order", %{conn: conn, suborder: suborder} do
      {:ok, show_live, html} = live(conn, ~p"/sub-orders/#{suborder}")

      assert html =~ "Show order position ID #{suborder.id}"
      assert html =~ "Payment date and time (UTC)"
    end

    test "updates a sub-order of an unpaid order within modal",
         %{conn: conn, suborder: suborder} do
      unpaid = suborder_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{unpaid}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit order position ID #{unpaid.id}")

      assert_patch(show_live, ~p"/sub-orders/#{unpaid}/show/edit")

      show_live
      |> change("#suborder-form", %{sub_order: @invalid_attrs})
      |> assert_match("can&#39;t be blank")

      submit(show_live, "#suborder-form", %{sub_order: @update_attrs})

      assert_patch(show_live, ~p"/sub-orders/#{unpaid}")
      assert(has_flash?(show_live, :info, "position ID #{unpaid.id} updat"))
      assert(render(show_live) =~ "4925")
    end

    test "cannot update a sub-order of a paid order within modal",
         %{conn: conn, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> refute_match("Edit order position ID #{suborder.id}")

      assert(has_flash?(show_live, "Cannot edit a position of a paid"))
    end

    test "deletes a sub-order of an unpaid order", %{conn: conn} do
      unpaid = suborder_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{unpaid}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn)

      assert(has_flash?(index_live, :info, "d order position ID #{unpaid.id}"))
      refute(has_element?(index_live, "#suborders-#{unpaid.id}"))
    end

    test "cannot delete a sub-order of a paid order",
         %{conn: conn, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_flash?(show_live, "Cannot delete a position of a paid"))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end
  end

  @doc """
  Check that the label of the `:user_id` input field changes
  when a valid user ID in inputted.
  """
  @spec assert_suborder_order_id_label_change(%View{}) :: boolean()
  def assert_suborder_order_id_label_change(live) do
    other_user = CloudDbUi.AccountsFixtures.user_fixture()
    unpaid = order_fixture(%{user_id: other_user.id})
    paid = order_paid_fixture(%{user_id: other_user.id})

    live
    |> change_order_id(unpaid.id)
    |> assert_match("ID (unpaid, belongs to #{other_user.email})")

    live
    |> change_order_id(paid.id)
    |> assert_match("ID (paid, belongs to #{other_user.email})")
  end

  @doc """
  Check that the label of the `:product_id` input field changes
  when a valid user ID in inputted.
  Also checks whether the "Current unit price of the product" changes.
  """
  @spec assert_suborder_product_id_label_change(%View{}) ::
          String.t() | {:error, {:redirect, redirect()}}
  def assert_suborder_product_id_label_change(live) do
    orderable = product_fixture(%{unit_price: "692.84", name: "weather"})

    non_orderable =
      product_fixture(%{orderable: false, unit_price: "346.42", name: "fence"})

    live
    |> change_product_id(orderable.id)
    |> tap(fn rendered ->
      assert_match(rendered, "ID (orderable, &quot;#{orderable.name}&quot;)")
      assert_match(rendered, "PLN 692.84")
    end)

    live
    |> change_product_id(non_orderable.id)
    |> tap(fn html ->
      assert_match(html, "ID (orderable, &quot;#{non_orderable.name}&quot;)")
      assert_match(html, "PLN 346.42")
    end)
  end

  # Returns a rendered `#suborder-form`.
  @spec change_form(%View{}, %{atom() => any()}) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_form(%View{} = live_view, suborder_data) do
    change(live_view, "#suborder-form", %{sub_order: suborder_data})
  end

  @spec change_order_id(%View{}, any()) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_order_id(%View{} = show_live, order_id) do
    change_form(show_live, %{order_id: order_id})
  end

  @spec change_product_id(%View{}, any()) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_product_id(%View{} = show_live, product_id) do
    change_form(show_live, %{product_id: product_id})
  end

  @spec change_unit_price(%View{}, any()) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_unit_price(%View{} = show_live, price) do
    change_form(show_live, %{unit_price: price})
  end
end
