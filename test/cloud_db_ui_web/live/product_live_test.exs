defmodule CloudDbUiWeb.ProductLiveTest do
  use CloudDbUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import CloudDbUi.{ProductsFixtures, OrdersFixtures, AccountsFixtures}

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.{DataCase, Products}
  alias CloudDbUi.Products.{Product, ProductType}
  alias CloudDbUi.Orders.SubOrder
  alias Phoenix.LiveViewTest.View
  alias Plug.Conn

  @type redirect_error() :: CloudDbUi.Type.redirect_error()
  @type upload_entry() :: CloudDbUi.Type.upload_entry()

  describe "Index, a not-logged-in guest" do
    setup [:create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      assert_redirect_to_log_in_page(conn, ~p"/products/new")
      assert_redirect_to_log_in_page(conn, ~p"/products/#{product}/edit")
    end

    test "lists only orderable products", %{conn: conn, product: product} do
      test_user_guest_lists_only_orderable_products(conn, product)
    end

    test "cannot delete a product in listing", %{conn: conn, product: prod} do
      test_user_guest_cannot_delete_product_in_listing(conn, prod)
    end

    test "gets redirected away when trying to order a product",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      order_product(index_live, product, 123)

      flash = assert_redirect(index_live, ~p"/log_in")

      assert(flash["error"] =~ "You must log in")
    end

    test "cannot see some filter form input fields", %{conn: conn} do
      test_user_guest_cannot_see_some_filter_form_input_fields(conn)
    end

    test "filters products by the name", %{conn: conn, product: product} do
      test_user_guest_filters_products_by_name(conn, product)
    end

    test "filters products by the description",
         %{conn: conn, product: product} do
      test_user_guest_filters_products_by_description(conn, product)
    end

    test "filters products by \"Price from\"",
         %{conn: conn, product: product} do
      test_user_guest_filters_products_by_price_from(conn, product)
    end

    test "filters products by \"Price to\"", %{conn: conn, product: product} do
      test_user_guest_filters_products_by_price_to(conn, product)
    end

    test "filters products by the product type name", %{conn: conn} do
      test_user_guest_filters_products_by_type_name(conn)
    end

    test "sorts products by ID", %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_id(conn, product)
    end

    test "sorts products by the name", %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_name(conn, product)
    end

    test "sorts products by the description",
         %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_description(conn, product)
    end

    test "sorts products by the unit price", %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_unit_price(conn, product)
    end

    test "sorts products by multiple columns",
         %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_multiple_columns(conn, product)
    end

    test "switches between pages of product results", %{conn: conn} do
      test_user_guest_switches_between_pages(conn)
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user, :create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      assert_redirect_to_index_or_show(conn, ~p"/products/new")
      assert_redirect_to_index_or_show(conn, ~p"/products/#{product}/edit")
    end

    test "lists only orderable products", %{conn: conn, product: product} do
      test_user_guest_lists_only_orderable_products(conn, product)
    end

    test "orders a valid quantity when there is no unpaid order",
         %{conn: conn, product: product} do
      {:ok, live, _html} = live(conn, ~p"/products")

      order_product(live, product, 77)

      assert(has_flash?(live, :info, "and added 77 pieces of #{product.name}"))
    end

    test "creates a sub-order of an unpaid order by ordering a valid quantity",
         %{conn: conn, product: product, user: user} do
      order_fixture(%{user: user})

      {:ok, index_live, _html} = live(conn, ~p"/products")

      order_product(index_live, product, 555)

      assert(has_flash?(index_live, :info, "Added 555 pieces of"))
    end

    test "updates a sub-order of an unpaid order by ordering a valid quantity",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user: user})

      suborder_fixture(%{order: order, product: product})

      {:ok, index_live, _html} = live(conn, ~p"/products")

      order_product(index_live, product, 999)

      assert(has_flash?(index_live, :info, "Added 999 pieces of"))
    end

    test "cannot order an invalid quantity",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_order_invalid_quantity(index_live, product)
    end

    test "cannot delete a product in listing", %{conn: conn, product: prod} do
      test_user_guest_cannot_delete_product_in_listing(conn, prod)
    end

    test "cannot order when the resulting quantity would exceed the limit",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user: user})
      suborder = suborder_fixture(%{order: order, product: product})

      {:ok, index_live, _html} = live(conn, ~p"/products")

      order_product(
        index_live,
        product,
        SubOrder.quantity_limit() - suborder.quantity + 1
      )

      assert(has_flash?(index_live, "already have #{suborder.quantity} pie"))
    end

    test "cannot see some filter form input fields", %{conn: conn} do
      test_user_guest_cannot_see_some_filter_form_input_fields(conn)
    end

    test "filters products by the name", %{conn: conn, product: product} do
      test_user_guest_filters_products_by_name(conn, product)
    end

    test "filters products by the description",
         %{conn: conn, product: product} do
      test_user_guest_filters_products_by_description(conn, product)
    end

    test "filters products by \"Price from\"",
         %{conn: conn, product: product} do
      test_user_guest_filters_products_by_price_from(conn, product)
    end

    test "filters products by \"Price to\"", %{conn: conn, product: product} do
      test_user_guest_filters_products_by_price_to(conn, product)
    end

    test "filters products by the product type name", %{conn: conn} do
      test_user_guest_filters_products_by_type_name(conn)
    end

    test "sorts products by ID", %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_id(conn, product)
    end

    test "sorts products by the name", %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_name(conn, product)
    end

    test "sorts products by the description",
         %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_description(conn, product)
    end

    test "sorts products by the unit price", %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_unit_price(conn, product)
    end

    test "sorts products by multiple columns",
         %{conn: conn, product: product} do
      test_user_guest_sorts_products_by_multiple_columns(conn, product)
    end

    test "switches between pages of product results", %{conn: conn} do
      test_user_guest_switches_between_pages(conn)
    end
  end

  describe "Index, an admin" do
    import CloudDbUi.OrdersFixtures

    setup [:register_and_log_in_admin, :create_unassignable_product_type]

    test "lists all products", %{conn: conn} do
      orderable = product_fixture()
      non_orderable = product_fixture(%{orderable: false})
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert(page_title(index_live) =~ "Listing products")
      assert(has_table_cell?(index_live, orderable.description))
      assert(has_element?(index_live, "th", "Type ID"))
      assert(has_element?(index_live, "th", "Orderable"))
      assert(has_element?(index_live, "th", "Paid orders"))
      assert(has_element?(index_live, "#products-#{orderable.id}"))
      assert(has_element?(index_live, "#products-#{non_orderable.id}"))
    end

    test "saves a new product", %{conn: conn, type: unassignable} do
      assignable = product_type_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 0)
      refute(has_element?(index_live, "input#product_name"))
      refute(has_element?(index_live, "img[alt='product image']"))

      click(index_live, "div.flex-none > a", "New product")

      assert(has_element?(index_live, "input#product_name"))
      assert_patch(index_live, ~p"/products/new")
      assert_form_errors(index_live, unassignable, assignable)
      assert_label_change(index_live)

      submit(index_live, "#product-form")

      assert_patch(index_live, ~p"/products")
      assert(has_element?(index_live, "img[alt='product image']"))
      assert(has_flash?(index_live, :info, "Product created successfully"))
      assert(has_table_cell?(index_live,  "NEWEST_desc"))
      assert_table_row_count(index_live, 1)
    end

    test "cannot save a new product when all types are not assignable",
         %{conn: conn, type: unassignable} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      refute(has_element?(index_live, "input#product_name"))

      click(index_live, "a", "New product")

      assert(has_element?(index_live, "input#product_name"))
      assert_patch(index_live, ~p"/products/new")
      refute(has_element?(index_live, "select#product_product_type_id"))
      assert_form_errors(index_live, unassignable, product_type_fixture())
      assert_label_change(index_live)

      submit(index_live, "#product-form")

      assert(has_element?(index_live, "input#product_name"))
      assert(has_flash?(index_live, "Product type can't be blank."))
    end

    test "updates a product in listing",
         %{conn: conn, type: unassignable} do
      product = product_fixture()
      assignable = product_type_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/products")

      refute(has_element?(index_live, "img[alt='product image']"))

      index_live
      |> click("#products-#{product.id} a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(index_live, ~p"/products/#{product}/edit")
      assert_form_errors(index_live, unassignable, assignable)
      assert_label_change(index_live)

      submit(index_live, "#product-form")

      index_live
      |> has_element?("#products-#{product.id} img[alt='product image']")
      |> assert()

      assert_patch(index_live, ~p"/products")
      assert(has_flash?(index_live, :info, "Product ID #{product.id} updated"))
      assert(has_table_cell?(index_live,  "NEWEST_desc"))

      assert_image_replacement(index_live, "#products-#{product.id} a", "Edit")
      assert_image_clearing(index_live, "#products-#{product.id} a", "Edit")
    end

    test "cannot change a product type when all types are not assignable",
         %{conn: conn, type: unassignable} do
      type = product_type_fixture()
      product = product_fixture(%{product_type: type})
      {:ok, _type_n} = Products.update_product_type(type, %{assignable: false})
      {:ok, index_live, _html} = live(conn, ~p"/products")

      index_live
      |> click("#products-#{product.id} a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(index_live, ~p"/products/#{product}/edit")
      refute(has_element?(index_live, "select#product_product_type_id"))

      index_live
      |> has_element?("#product-form label", "Unable to change product type:")
      |> assert()

      assert_form_errors(index_live, unassignable, product_type_fixture())
      assert_label_change(index_live)

      submit(index_live, "#product-form")

      assert_patch(index_live, ~p"/products")
      assert(has_flash?(index_live, :info, "Product ID #{product.id} updated"))
      assert(has_table_cell?(index_live,  "NEWEST_desc"))
    end

    test "deletes a product that has no paid orders", %{conn: conn} do
      product = product_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 1)

      click(index_live, "#products-#{product.id} a", "Delete")

      assert(has_flash?(index_live, :info, "Deleted product ID #{product.id}"))
      refute(has_element?(index_live, "#products-#{product.id}"))
      assert_table_row_count(index_live, 0)
    end

    test "cannot delete a product that has any paid orders of it",
         %{conn: conn} do
      product = product_fixture()
      user = user_fixture()
      order = order_fixture(%{user: user})

      suborder_fixture(%{order: order, product: product})
      DataCase.set_as_paid(order, user)

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 1)

      click(index_live, "#products-#{product.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete a product, paid orders of"))
      assert(has_element?(index_live, "#products-#{product.id}"))
      assert_table_row_count(index_live, 1)
    end

    test "cannot order a product", %{conn: conn} do
      product = product_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/products")

      submit(
        index_live,
        "#order-form-#{product.id}",
        %{sub_order: %{quantity: 99}}
      )

      assert(has_flash?(index_live, "An administrator may not order"))
    end

    test "can see all filter form input fields", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert(has_element?(index_live, "#flop_filters_8_value"))
      refute(has_element?(index_live, "#flop_filters_9_value"))
    end

    test "filters products by the name", %{conn: conn} do
      [product, other] = Enum.map(["N1", "n2"], &product_fixture(%{name: &1}))
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 0, "¢")

      assert_table_row_count(index_live, 0)

      filter(index_live, 0, String.upcase(product.name))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))

      filter(index_live, 0, String.upcase(other.name))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))
      assert_filter_form_errors(index_live, 0, "text")
      assert_filter_param_handling(conn, "products", 0, :name_trimmed, :ilike)
    end

    test "filters products by the description", %{conn: conn} do
      [product, other] =
        Enum.map(["Desc_1", "desc_2"], &product_fixture(%{description: &1}))

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 1, "¢")

      assert_table_row_count(index_live, 0)

      filter(index_live, 1, String.upcase(product.description))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))

      filter(index_live, 1, String.upcase(other.description))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))
      assert_filter_form_errors(index_live, 1, "text")

      assert_filter_param_handling(
        conn,
        "products",
        1,
        :description_trimmed,
        :ilike
      )
    end

    test "filters products by \"Created from\"", %{conn: conn} do
      [product, other] = Enum.map(0..1, fn _ -> product_fixture() end)

      DataCase.update_inserted_at(product, "2020-02-15 15:00:00Z")
      DataCase.update_inserted_at(other, "2020-02-15 10:00:00Z")

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 2, "2020-02-15 10:00")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 2, "2020-02-15 10:01")

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))
      refute(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 2, "2020-02-15 15:01")

      assert_table_row_count(index_live, 0)
      refute(has_table_row?(index_live, "#products", product, [:id, :name]))
      refute(has_table_row?(index_live, "#products", other, [:id, :name]))
      assert_filter_form_errors(index_live, 2, 3, "datetime-local")
      assert_filter_param_handling(conn, "products", 2, :inserted_at, :>=)
    end

    test "filters products by \"Created to\"", %{conn: conn} do
      [product, other] = Enum.map(0..1, fn _ -> product_fixture() end)

      DataCase.update_inserted_at(product, "2020-02-15 15:00:00Z")
      DataCase.update_inserted_at(other, "2020-02-15 10:00:00Z")

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 3, "2020-02-15 15:00")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 3, "2020-02-15 14:59")

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#products", product, [:id, :name]))
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 3, "2020-02-15 09:59")

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 3, 2, "datetime-local")
      assert_filter_param_handling(conn, "products", 3, :inserted_at, :<=)
    end

    test "filters products by \"Price from\"", %{conn: conn} do
      [product, other] = Enum.map([99, 7], &product_fixture(%{unit_price: &1}))
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 4, other.unit_price)

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 4, Decimal.add(other.unit_price, "0.01"))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))
      refute(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 4, Decimal.add(product.unit_price, "0.01"))

      assert_table_row_count(index_live, 0)
      refute(has_table_row?(index_live, "#products", product, [:id, :name]))
      refute(has_table_row?(index_live, "#products", other, [:id, :name]))
      assert_filter_form_errors(index_live, 4, 5, "decimal")

      assert_filter_param_handling(
        conn,
        "products",
        4,
        :unit_price_trimmed,
        :>=
      )
    end

    test "filters products by \"Price to\"", %{conn: conn} do
      [product, other] = Enum.map([99, 7], &product_fixture(%{unit_price: &1}))
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 5, product.unit_price)

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 5, Decimal.sub(product.unit_price, "0.01"))

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#products", product, [:id, :name]))
      assert(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 5, Decimal.sub(other.unit_price, "0.01"))

      assert_table_row_count(index_live, 0)
      refute(has_table_row?(index_live, "#products", product, [:id, :name]))
      refute(has_table_row?(index_live, "#products", other, [:id, :name]))

      filter(index_live, 5, 0)

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 5, 4, "decimal")

      assert_filter_param_handling(
        conn,
        "products",
        5,
        :unit_price_trimmed,
        :<=
      )
    end

    test "filters products by the product type name", %{conn: conn} do
      type = product_type_fixture(%{name: "New type"})
      product = product_fixture(%{product_type: type})
      other_type = product_type_fixture(%{name: "Other type"})
      other_product = product_fixture(%{product_type: other_type})
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 6, String.upcase(type.name))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", product, [:id, :name]))

      filter(index_live, 6, String.upcase(other_type.name))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", other_product, [:name]))

      filter(index_live, 6, type.name <> "e")

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 6, "text")

      assert_filter_param_handling(
        conn,
        "products",
        6,
        :product_type_name,
        :ilike
      )
    end

    test "filters products by whether a product is orderable", %{conn: conn} do
      orderable = product_fixture()
      unorderable = product_fixture(%{orderable: false})
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 7, true)

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", orderable, [:id, :name]))
      refute(has_table_row?(index_live, "#products", unorderable, [:name]))

      filter(index_live, 7, false)

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#products", orderable, [:id, :name]))
      assert(has_table_row?(index_live, "#products", unorderable, [:name]))
      assert_filter_param_handling(conn, "products", 7, :orderable, :==)
    end

    test "filters products by whether a product has any paid orders",
         %{conn: conn} do
      user = user_fixture()
      order = order_fixture(%{user: user})
      with_orders = product_fixture()
      orderless = product_fixture()

      suborder_fixture(%{order: order, product: with_orders})
      DataCase.set_as_paid(order, user)

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 2)

      filter(index_live, 8, true)

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#products", with_orders, [:name]))
      refute(has_table_row?(index_live, "#products", orderless, [:id, :name]))

      filter(index_live, 8, false)

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#products", with_orders, [:name]))
      assert(has_table_row?(index_live, "#products", orderless, [:id, :name]))
      assert_filter_param_handling(conn, "products", 8, :has_paid_orders, :!=)
    end

    test "sorts products by ID", %{conn: conn} do
      ids = Enum.map(0..2, fn _ -> product_fixture().id end)
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_sorting(index_live, ids, ~r/^\s*ID\s*$/)
      assert_sort_param_handling(conn, "products", :id)
    end

    test "sorts products by product type ID", %{conn: conn} do
      ids = Enum.map(0..2, fn _ -> product_fixture().product_type_id end)
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_sorting(index_live, ids, "Type ID")
      assert_sort_param_handling(conn, "products", :product_type_id)
    end

    test "sorts products by the name", %{conn: conn} do
      [product, other] = Enum.map(["N1", "n2"], &product_fixture(%{name: &1}))
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_sorting(index_live, [product.name, other.name], "Name")
      assert_sort_param_handling(conn, "products", :name)
    end

    test "sorts products by the description", %{conn: conn} do
      descriptions =
        Enum.map(["Product", "Other"], fn desc ->
          product_fixture(%{description: desc <> " description"}).description
        end)

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_sorting(index_live, descriptions, "Description")
      assert_sort_param_handling(conn, "products", :description)
    end

    test "sorts products by the unit price", %{conn: conn} do
      prices =
        Enum.map([1, 9], fn price ->
          product_fixture(%{unit_price: price}).unit_price
        end)

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_sorting(index_live, prices, "Unit price")
      assert_sort_param_handling(conn, "products", :unit_price)
    end

    test "sorts products by the creation date", %{conn: conn} do
      values =
        Enum.map([15, 10], fn hour ->
          value = "2020-02-15 #{hour}:00:00"

          {:ok, _updated} =
            product_fixture()
            |> DataCase.update_inserted_at(value <> "Z")

          value
        end)

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_sorting(index_live, values, "Creation date and time")
      assert_sort_param_handling(conn, "products", :inserted_at)
    end

    test "sorts products by whether they are orderable", %{conn: conn} do
      Enum.each([true, false], &product_fixture(%{orderable: &1}))

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_sorting(index_live, ["Yes", ""], "Orderable")
      assert_sort_param_handling(conn, "products", :orderable)
    end

    test "sorts products by multiple columns", %{conn: conn} do
      Enum.each([{["A", "Z"], false}, {["B"], true}], fn {names, orderable} ->
        names
        |> List.duplicate(2)
        |> List.flatten()
        |> Enum.each(&product_fixture(%{name: &1, orderable: orderable}))
      end)

      by_name_id = order_params([:name, :id], [:asc, :desc])
      {:ok, index_live, _html} = live(conn, ~p"/products?#{by_name_id}")
      ids_desc = column_values(index_live, 1)

      # "Name" column values.
      assert(column_values(index_live, 4) == ["A", "A", "B", "B", "Z", "Z"])
      assert_table_row_count(index_live, 6)
      assert(sorted?(Enum.take(ids_desc, 2), :desc))
      assert(sorted?(Enum.take(ids_desc, -2), :desc))
      refute(sorted?(ids_desc, :desc))

      by_orderable_id = order_params([:orderable, :id], [:desc, :asc])
      {:ok, live, _html} = live(conn, ~p"/products?#{by_orderable_id}")
      ids_asc = column_values(live, 1)

      # "Orderable" column values.
      assert(column_values(live, 8) == ["Yes", "Yes", "", "", "", ""])
      assert(sorted?(Enum.take(ids_asc, 2), :asc))
      assert(sorted?(Enum.take(ids_asc, -4), :asc))
      refute(sorted?(ids_asc, :asc))
    end

    test "switches between pages of product results", %{conn: conn} do
      Enum.each(0..25, fn _ -> product_fixture() end)

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_table_row_count(index_live, 25)
      assert(has_n_children?(index_live, "nav.pagination > ul", 2))

      index_live
      |> has_element?("#pagination-counter", "26 results (25 on the current")
      |> assert()

      {:ok, live, _html} = live(conn, ~p"/products")

      click(live, "nav.pagination > ul > :nth-child(2) > a")

      assert_table_row_count(live, 1)

      live
      |> has_element?("#pagination-counter", "26 results (1 on the current")
      |> assert()

      assert_page_param_handling(conn, "products")
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      assert_redirect_to_log_in_page(conn, ~p"/products/#{product}/show/edit")
    end

    test "can view an orderable product", %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert(page_title(show_live) =~ "Show product ID #{product.id}")
      assert(list_item_value(show_live, "Description") == product.description)
      refute(has_element?(show_live, "dt", "Type ID"))
    end

    test "cannot view a non-orderable product", %{conn: conn} do
      test_user_guest_cannot_view_unorderable_product(conn)
    end

    test "gets redirected away when trying to order a product",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products/#{product}")

      order_product(index_live, product, 123)

      flash = assert_redirect(index_live, ~p"/log_in")

      assert(flash["error"] =~ "You must log in")
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      assert_redirect_to_index_or_show(
        conn,
        ~p"/products/#{product}/show/edit"
      )
    end

    test "can view an orderable product", %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert(page_title(show_live) =~ "Show product ID #{product.id}")
      assert(list_item_value(show_live, "Description") == product.description)
      refute(has_element?(show_live, "dt", "Type ID"))
    end

    test "cannot view a non-orderable product", %{conn: conn} do
      test_user_guest_cannot_view_unorderable_product(conn)
    end

    test "orders a valid quantity when there is no unpaid order",
         %{conn: conn, product: product} do
      {:ok, live, _html} = live(conn, ~p"/products/#{product}")

      order_product(live, product, 77)

      assert(has_flash?(live, :info, "and added 77 pieces of #{product.name}"))
    end

    test "creates a sub-order of an unpaid order by ordering a valid quantity",
         %{conn: conn, product: product, user: user} do
      order_fixture(%{user: user})

      {:ok, live, _html} = live(conn, ~p"/products/#{product}")

      order_product(live, product, 555)

      assert(has_flash?(live, :info, "Added 555 pieces of"))
    end

    test "updates a sub-order of an unpaid order by ordering a valid quantity",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user: user})

      suborder_fixture(%{order: order, product: product})

      {:ok, live, _html} = live(conn, ~p"/products/#{product}")

      order_product(live, product, 999)

      assert(has_flash?(live, :info, "Added 999 pieces of"))
    end

    test "cannot order an invalid quantity",
         %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert_order_invalid_quantity(show_live, product)
    end

    test "cannot order when the resulting quantity would exceed the limit",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user: user})
      suborder = suborder_fixture(%{order: order, product: product})

      {:ok, live, _html} = live(conn, ~p"/products/#{product}")

      order_product(
        live,
        product,
        SubOrder.quantity_limit() - suborder.quantity + 1
      )

      assert(has_flash?(live, "already have #{suborder.quantity} pieces"))
    end
  end

  describe "Show, an admin" do
    setup [:register_and_log_in_admin, :create_unassignable_product_type]

    test "can view any product", %{conn: conn} do
      product = product_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert(page_title(show_live) =~ "Show product ID #{product.id}")
      assert(list_item_value(show_live, "Description") == product.description)
      assert(has_table_cell?(show_live, "#{product.product_type_id}"))

      non_orderable = product_fixture(%{orderable: false, description: "dESc"})
      {:ok, live, _html} = live(conn, ~p"/products/#{non_orderable}")

      assert(page_title(live) =~ "Show product ID #{non_orderable.id}")
      assert(list_item_value(live, "Description") == non_orderable.description)
      assert(has_table_cell?(show_live, "#{product.product_type_id}"))
    end

    test "updates a product within modal", %{conn: conn, type: unassignable} do
      product = product_fixture()
      assignable = product_type_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      refute(has_element?(show_live, "dd > img[alt='product image']"))

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(show_live, ~p"/products/#{product}/show/edit")
      assert(has_element?(show_live, "select#product_product_type_id"))
      assert_form_errors(show_live, unassignable, assignable)
      assert_label_change(show_live)

      submit(show_live, "#product-form")

      assert_patch(show_live, ~p"/products/#{product}")
      assert(has_element?(show_live, "dd > img[alt='product image']"))
      assert(has_flash?(show_live, :info, "Product ID #{product.id} updated"))
      assert(list_item_value(show_live, "Description") == "NEWEST_desc")
      assert_image_replacement(show_live, "div.flex-none > a", "Edit")
      assert_image_clearing(show_live, "div.flex-none > a", "Edit")
    end

    test "cannot change a product type when all types are not assignable",
         %{conn: conn, type: unassignable} do
      type = product_type_fixture()
      product = product_fixture(%{product_type: type})
      {:ok, _type_n} = Products.update_product_type(type, %{assignable: false})
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(show_live, ~p"/products/#{product}/show/edit")
      refute(has_element?(show_live, "select#product_product_type_id"))

      show_live
      |> has_element?("#product-form label", "Unable to change product type:")
      |> assert()

      assert_form_errors(show_live, unassignable, product_type_fixture())
      assert_label_change(show_live)

      submit(show_live, "#product-form")

      assert_patch(show_live, ~p"/products/#{product}")
      assert(has_flash?(show_live, :info, "Product ID #{product.id} updated"))
      assert(list_item_value(show_live, "Description") == "NEWEST_desc")
    end

    test "deletes a product that has no paid orders", %{conn: conn} do
      product = product_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn, ~p"/products")

      assert(has_flash?(index_live, :info, "Deleted product ID #{product.id}"))
      refute(has_element?(index_live, "#products-#{product.id}"))
      assert_table_row_count(index_live, 0)
    end

    test "cannot delete a product that has any paid orders of it",
         %{conn: conn} do
      product = product_fixture()
      user = user_fixture()
      order = order_fixture(%{user: user})

      suborder_fixture(%{order: order, product: product})
      DataCase.set_as_paid(order, user)

      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
      assert(has_flash?(show_live, "Cannot delete a product, paid orders of"))
    end
  end

  @spec test_user_guest_lists_only_orderable_products(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_lists_only_orderable_products(conn, product) do
    unorderable = product_fixture(%{orderable: false})
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert(page_title(index_live) =~ "Listing products")
    assert_table_row_count(index_live, 1)
    refute(has_element?(index_live, "th", "Type ID"))
    assert(has_table_row?(index_live, "#products", product, [:id, :name]))
    refute(has_table_row?(index_live, "#products", unorderable, [:id, :name]))
  end

  @spec test_user_guest_cannot_view_unorderable_product(%Conn{}) ::
            boolean()
  defp test_user_guest_cannot_view_unorderable_product(%Conn{} = conn) do
    unorderable = product_fixture(%{orderable: false})

    try do
      live(conn, ~p"/products/#{unorderable}")

      assert(false)
    catch
      :exit, {value, {Phoenix.LiveViewTest, :live, paths}} ->
        assert(value.status == 404)
        assert(paths == [~p"/products/#{unorderable}"])
    end
  end

  @spec test_user_guest_cannot_delete_product_in_listing(
          %Conn{},
          %Product{}
        ) :: boolean()
  defp test_user_guest_cannot_delete_product_in_listing(conn, product) do
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_table_row_count(index_live, 1)
    assert(has_element?(index_live, "#products-#{product.id}"))

    click(index_live, "#products-#{product.id} a", "Delete")

    assert(has_flash?(index_live, "Only an administrator may delete products"))
    assert_table_row_count(index_live, 1)
    assert(has_element?(index_live, "#products-#{product.id}"))
  end

  @spec test_user_guest_cannot_see_some_filter_form_input_fields(%Conn{}) ::
          boolean()
  defp test_user_guest_cannot_see_some_filter_form_input_fields(conn) do
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert(has_element?(index_live, "#flop_filters_4_value"))
    refute(has_element?(index_live, "#flop_filters_5_value"))
  end

  @spec test_user_guest_filters_products_by_name(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_filters_products_by_name(%Conn{} = conn, product) do
    other = product_fixture(%{name: "Other name"})
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_table_row_count(index_live, 2)

    filter(index_live, 0, "¢")

    assert_table_row_count(index_live, 0)

    filter(index_live, 0, String.upcase(product.name))

    assert_table_row_count(index_live, 1)
    assert(has_table_row?(index_live, "#products", product, [:id, :name]))

    filter(index_live, 0, String.upcase(other.name))

    assert_table_row_count(index_live, 1)
    assert(has_table_row?(index_live, "#products", other, [:id, :name]))
    assert_filter_form_errors(index_live, 0, "text")
    assert_filter_param_handling(conn, "products", 0, :name_trimmed, :ilike)
  end

  @spec test_user_guest_filters_products_by_description(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_filters_products_by_description(conn, product) do
    other = product_fixture(%{description: "Other description"})
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_table_row_count(index_live, 2)

    filter(index_live, 1, "¢")

    assert_table_row_count(index_live, 0)

    filter(index_live, 1, String.upcase(product.description))

    assert_table_row_count(index_live, 1)
    assert(has_table_row?(index_live, "#products", product, [:id, :name]))

    filter(index_live, 1, String.upcase(other.description))

    assert_table_row_count(index_live, 1)
    assert(has_table_row?(index_live, "#products", other, [:id, :name]))
    assert_filter_form_errors(index_live, 1, "text")

    assert_filter_param_handling(
      conn,
      "products",
      1,
      :description_trimmed,
      :ilike
    )
  end

  @spec test_user_guest_filters_products_by_price_from(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_filters_products_by_price_from(conn, product) do
    other = product_fixture(%{unit_price: 7})
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_table_row_count(index_live, 2)

    filter(index_live, 2, other.unit_price)

    assert_table_row_count(index_live, 2)
    assert(has_table_row?(index_live, "#products", product, [:id, :name]))
    assert(has_table_row?(index_live, "#products", other, [:id, :name]))

    filter(index_live, 2, Decimal.add(other.unit_price, "0.01"))

    assert_table_row_count(index_live, 1)
    assert(has_table_row?(index_live, "#products", product, [:id, :name]))
    refute(has_table_row?(index_live, "#products", other, [:id, :name]))

    filter(index_live, 2, Decimal.add(product.unit_price, "0.01"))

    assert_table_row_count(index_live, 0)
    refute(has_table_row?(index_live, "#products", product, [:id, :name]))
    refute(has_table_row?(index_live, "#products", other, [:id, :name]))
    assert_filter_form_errors(index_live, 2, 3, "decimal")

    assert_filter_param_handling(
      conn,
      "products",
      2,
      :unit_price_trimmed,
      :>=
    )
  end

  @spec test_user_guest_filters_products_by_price_to(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_filters_products_by_price_to(%Conn{} = conn, product) do
    other = product_fixture(%{unit_price: 7})
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_table_row_count(index_live, 2)

    filter(index_live, 3, product.unit_price)

    assert_table_row_count(index_live, 2)
    assert(has_table_row?(index_live, "#products", product, [:id, :name]))
    assert(has_table_row?(index_live, "#products", other, [:id, :name]))

    filter(index_live, 3, Decimal.sub(product.unit_price, "0.01"))

    assert_table_row_count(index_live, 1)
    refute(has_table_row?(index_live, "#products", product, [:id, :name]))
    assert(has_table_row?(index_live, "#products", other, [:id, :name]))

    filter(index_live, 3, Decimal.sub(other.unit_price, "0.01"))

    assert_table_row_count(index_live, 0)
    refute(has_table_row?(index_live, "#products", product, [:id, :name]))
    refute(has_table_row?(index_live, "#products", other, [:id, :name]))

    filter(index_live, 3, 0)

    assert_table_row_count(index_live, 0)
    assert_filter_form_errors(index_live, 3, 2, "decimal")

    assert_filter_param_handling(
      conn,
      "products",
      3,
      :unit_price_trimmed,
      :<=
    )
  end

  @spec test_user_guest_filters_products_by_type_name(%Conn{}) :: boolean()
  defp test_user_guest_filters_products_by_type_name(%Conn{} = conn) do
    type = product_type_fixture(%{name: "New type"})
    product = product_fixture(%{product_type: type})
    other_type = product_type_fixture(%{name: "Other type"})
    other_product = product_fixture(%{product_type: other_type})
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_table_row_count(index_live, 3)

    filter(index_live, 4, String.upcase(type.name))

    assert_table_row_count(index_live, 1)
    assert(has_table_row?(index_live, "#products", product, [:id, :name]))

    filter(index_live, 4, String.upcase(other_type.name))

    assert_table_row_count(index_live, 1)
    assert(has_table_row?(index_live, "#products", other_product, [:name]))

    filter(index_live, 4, type.name <> "e")

    assert_table_row_count(index_live, 0)
    assert_filter_form_errors(index_live, 4, "text")

    assert_filter_param_handling(
      conn,
      "products",
      4,
      :product_type_name,
      :ilike
    )
  end

  @spec test_user_guest_sorts_products_by_id(%Conn{}, %Product{}) :: boolean()
  defp test_user_guest_sorts_products_by_id(%Conn{} = conn, product) do
    ids = [product.id | Enum.map(0..2, fn _ -> product_fixture().id end)]
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_sorting(index_live, ids, ~r/^\s*ID\s*$/)
    assert_sort_param_handling(conn, "products", :id)
  end

  @spec test_user_guest_sorts_products_by_name(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_sorts_products_by_name(%Conn{} = conn, product) do
    other = product_fixture(%{name: "Other name"})
    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_sorting(index_live, [product.name, other.name], "Name")
    assert_sort_param_handling(conn, "products", :name)
  end

  @spec test_user_guest_sorts_products_by_description(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_sorts_products_by_description(conn, product) do
    other = product_fixture(%{description: "Other description"})
    {:ok, live, _html} = live(conn, ~p"/products")

    assert_sorting(live, [product.description, other.description], "Descrip")
    assert_sort_param_handling(conn, "products", :description)
  end

  @spec test_user_guest_sorts_products_by_unit_price(%Conn{}, %Product{}) ::
          boolean()
  defp test_user_guest_sorts_products_by_unit_price(conn, product) do
    new_prices =
      Enum.map([1, 9], &product_fixture(%{unit_price: &1}).unit_price)

    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_sorting(index_live, [product.unit_price | new_prices], "Unit pri")
    assert_sort_param_handling(conn, "products", :unit_price)
  end

  @spec test_user_guest_sorts_products_by_multiple_columns(
          %Conn{},
          %Product{}
        ) :: boolean()
  defp test_user_guest_sorts_products_by_multiple_columns(conn, prod) do
    Enum.each([{"A", 4}, {"Z", 150}], fn {name, price} ->
      name
      |> List.duplicate(2)
      |> Enum.each(&product_fixture(%{name: &1, unit_price: price}))
    end)

    by_name_id = order_params([:name, :id], [:asc, :desc])
    {:ok, index_live, _html} = live(conn, ~p"/products?#{by_name_id}")
    ids_desc = column_values(index_live, 1)

    # "Name" column values.
    assert(column_values(index_live, 3) == ["A", "A", prod.name, "Z", "Z"])
    assert_table_row_count(index_live, 5)
    assert(sorted?(Enum.take(ids_desc, 2), :desc))
    assert(sorted?(Enum.take(ids_desc, -2), :desc))
    refute(sorted?(ids_desc, :desc))

    by_orderable_id = order_params([:unit_price, :id], [:desc, :asc])
    {:ok, live, _html} = live(conn, ~p"/products?#{by_orderable_id}")
    ids_asc = column_values(live, 1)

    # "Unit price" column values.
    live
    |> column_values(5)
    |> Kernel.==(["150.00", "150.00", "120.50", "4.00", "4.00"])
    |> assert()

    assert(sorted?(Enum.take(ids_asc, 2), :asc))
    assert(sorted?(Enum.take(ids_asc, -2), :asc))
    refute(sorted?(ids_asc, :asc))
  end

  @spec test_user_guest_switches_between_pages(%Conn{}) :: boolean()
  defp test_user_guest_switches_between_pages(%Conn{} = conn) do
    Enum.each(0..24, fn _ -> product_fixture() end)

    {:ok, index_live, _html} = live(conn, ~p"/products")

    assert_table_row_count(index_live, 25)
    assert(has_n_children?(index_live, "nav.pagination > ul", 2))

    index_live
    |> has_element?("#pagination-counter", "26 results (25 on the current")
    |> assert()

    {:ok, live, _html} = live(conn, ~p"/products")

    click(live, "nav.pagination > ul > :nth-child(2) > a")

    assert_table_row_count(live, 1)

    live
    |> has_element?("#pagination-counter", "26 results (1 on the current")
    |> assert()

    assert_page_param_handling(conn, "products")
  end

  # Check `:error` flash titles when a user attempts
  # to add an invalid quantity of a product to an order.
  @spec assert_order_invalid_quantity(%View{}, %Product{}) :: boolean()
  defp assert_order_invalid_quantity(%View{} = live_view, product) do
    order_product(live_view, product, nil)

    assert(has_flash?(live_view, "Invalid quantity."))

    order_product(live_view, product, 0)

    assert(has_flash?(live_view, "Cannot order fewer than one piece"))

    order_product(live_view, product, SubOrder.quantity_limit() + 1)

    assert(has_flash?(live_view, "Cannot order more than"))
  end

  # Check that the `:name` and the `:description` labels display
  # character count.
  @spec assert_label_change(%View{}) :: boolean()
  defp assert_label_change(%View{} = live_view) do
    change_form(live_view, %{name: nil})

    assert(label_text(live_view, :name) == "Name")

    change_form(live_view, %{name: "we"})

    assert(label_text(live_view, :name) == "Name (2/60 characters)")

    change_form(live_view, %{description: nil})

    assert(label_text(live_view, :description) == "Description")

    change_form(live_view, %{description: "NEWEST_desc"})

    assert(label_text(live_view, :description) =~ "Description (11/200 charac")
  end

  @spec assert_form_errors(%View{}, %ProductType{}, %ProductType{}) ::
          boolean()
  defp assert_form_errors(%View{} = lv, unassignable, assignable) do
    assert_form_no_input_related_errors(lv)
    assert_form_name_errors(lv)

    cond do
      has_element?(lv, "#product-form select#product_product_type_id") ->
        assert_form_product_type_id_errors(lv, unassignable, assignable)

      !has_element?(lv, "#product-form label", "nable to change product ty") ->
        lv
        |> has_form_error?("#product-form", "unable to set product type: no")
        |> assert()

      true -> true
    end

    change_form(lv, %{description: String.duplicate("i", 201)})

    lv
    |> has_form_error?("#product-form", :description, "at most 200 character")
    |> assert()

    change_form(lv, %{description: "NEWEST_desc"})

    assert_form_unit_price_errors(lv)
    assert_form_upload_errors(lv)
    assert_form_no_input_related_errors(lv)
  end

  @spec assert_form_no_input_related_errors(%View{}) :: boolean()
  defp assert_form_no_input_related_errors(%View{} = live_view) do
    errors = form_errors(live_view, "#product-form")

    assert(errors == [] or errors == ["unable to set product type: no"])
  end

  @spec assert_form_name_errors(%View{}) :: boolean()
  defp assert_form_name_errors(%View{} = live) do
    change_form(live, %{name: nil})

    assert(form_errors(live, "#product-form", :name) == ["can&#39;t be blank"])

    change_form(live, %{name: String.duplicate("i", 61)})

    live
    |> has_form_error?("#product-form", :name, "uld be at most 60 character(s")
    |> assert()

    change_form(live, %{name: "some name"})

    assert(form_errors(live, "#product-form", :name) == [])
  end

  @spec assert_form_product_type_id_errors(
          %View{},
          %ProductType{},
          %ProductType{}
        ) :: boolean()
  defp assert_form_product_type_id_errors(live, unassignable, assignable) do
    options = options_of_select(live, :product_type_id)

    if "" in Map.keys(options) do
      change_form(live, %{product_type_id: ""})

      live
      |> has_form_error?("#product-form", :product_type_id, "n&#39;t be blank")
      |> assert()
    end

    # Make sure that the unassignable type is not in the options.
    refute("#{unassignable.id}" in Map.keys(options))
    refute("#{unassignable.name}" in Map.values(options))
    assert("#{assignable.id}" in Map.keys(options))
    assert("#{assignable.name}" in Map.values(options))

    change_form(live, %{product_type_id: assignable.id})

    assert(form_errors(live, "#product-form", :product_type_id) == [])
  end

  @spec assert_form_unit_price_errors(%View{}) :: boolean()
  defp assert_form_unit_price_errors(%View{} = live) do
    assert_decimal_field_errors(live, "#product-form", :product, :unit_price)

    change_form(live, %{unit_price: -1})

    live
    |> has_form_error?("#product-form", :unit_price, "must not be negative")
    |> assert()

    change_form(live, %{unit_price: Decimal.add(User.balance_limit(), "0.01")})

    live
    |> has_form_error?(
      "#product-form",
      :unit_price,
      "must be less than or equal to #{User.balance_limit()}"
    )
    |> assert()

    change_form(live, %{unit_price: 123.45})

    assert(form_errors(live, "#product-form", :unit_price) == [])
  end

  @spec assert_form_upload_errors(%View{}) :: boolean()
  defp assert_form_upload_errors(%View{} = live) do
    refute(has_element?(live, "button", "Cancel upload"))

    artificial_bad_type = upload_entry("text.txt", 1_024)

    assert(form_upload_errors(live, artificial_bad_type) == [:not_accepted])
    assert_uploaded_form_image_progress(live, artificial_bad_type, 0)

    click(live, "button", "Cancel upload")

    artificial_valid = upload_entry("valid image.png", 5_242_880)

    assert(form_upload_errors(live, artificial_valid) == [])
    assert_uploaded_form_image_progress(live, artificial_valid, 100)

    click(live, "button", "Cancel upload")

    artificial_over_limit = upload_entry("over limit.png", 6_242_881)

    assert(form_upload_errors(live, artificial_over_limit) == [:too_large])
    assert_uploaded_form_image_progress(live, artificial_over_limit, 0)

    click(live, "button", "Cancel upload")

    from_file = upload_entry!()

    assert(form_upload_errors(live, from_file) == [])
    assert_uploaded_form_image_progress(live, from_file, 100)
  end

  # Expects a product to already have an image path.
  @spec assert_image_replacement(%View{}, String.t(), String.t()) ::
          String.t() | redirect_error()
  defp assert_image_replacement(%View{} = live, selector, txt_filter) do
    click(live, selector, txt_filter)

    assert(has_element?(live, "#product-form dt", "Current image path"))
    assert(has_element?(live, "#product-form dd > img[alt='product image']"))
    assert(has_element?(live, "div[phx-feedback-for=remove_image]"))

    path_prev = form_list_item_value(live, "Current image path")

    assert(String.starts_with?(path_prev, "/files/"))
    assert_uploaded_form_image_progress(live, upload_entry!(), 100)

    # Submit with a new image.
    submit(live, "#product-form")

    assert(has_flash?(live, :info, "updated successfully."))

    click(live, selector, txt_filter)

    path_new = form_list_item_value(live, "Current image path")

    assert(String.starts_with?(path_new, "/files/"))
    assert(path_new != path_prev)
    assert_uploaded_form_image_progress(live, upload_entry!(), 100)

    # Checking "Remove the current image" cancels the upload.
    change(live, "#product-form", %{remove_image: true})
    change(live, "#product-form", %{remove_image: false})

    refute(has_element?(live, "button", "Cancel upload"))
    refute(has_element?(live, "div[phx-drop-target] > progress[value]"))

    # Submit without changing the image.
    submit(live, "#product-form")

    assert(has_flash?(live, :info, "updated successfully."))

    click(live, selector, txt_filter)

    assert(form_list_item_value(live, "Current image path") == path_new)

    # Submit without changing anything (close the modal).
    submit(live, "#product-form")
  end

  @spec assert_image_clearing(%View{}, String.t(), String.t()) ::
          String.t() | redirect_error()
  defp assert_image_clearing(%View{} = live, selector, txt_filter) do
    click(live, selector, txt_filter)

    assert(has_element?(live, "#product-form dt", "Current image path"))
    assert(has_element?(live, "#product-form dd > img[alt='product image']"))
    assert(has_element?(live, "div[phx-feedback-for=remove_image]"))

    change(live, "#product-form", %{remove_image: true})

    submit(live, "#product-form")

    click(live, selector, txt_filter)

    assert(has_element?(live, "input#product_name"))
    refute(has_element?(live, "#product-form dt", "Current image path"))
    refute(has_element?(live, "#product-form dd > img[alt='product image']"))
    refute(has_element?(live, "div[phx-feedback-for=remove_image]"))

    # Submit without changing anything (close the modal).
    submit(live, "#product-form")
  end

  # Uses `render_upload()` within `upload_form_image()`.
  @spec assert_uploaded_form_image_progress(
          %View{},
          upload_entry(),
          non_neg_integer()
        ) :: boolean()
  defp assert_uploaded_form_image_progress(%View{} = live, entry, expected) do
    upload_form_image(live, entry)

    assert(has_element?(live, "button", "Cancel upload"))
    assert(upload_progress(live) == "#{expected}")
  end

  # Make the form send a `phx-submit` event with `product.id`
  # and `quantity`.
  @spec order_product(%View{}, %Product{}, any()) ::
          String.t() | redirect_error()
  defp order_product(%View{} = index_live, product, quantity) do
    submit(
      index_live,
      "#order-form-#{product.id}",
      %{sub_order: %{quantity: quantity}}
    )
  end

  # Should return a rendered `#product-form`.
  @spec change_form(%View{}, %{atom() => any()}) ::
          String.t() | redirect_error()
  defp change_form(%View{} = live_view, product_data) do
    change(live_view, "#product-form", %{product: product_data})
  end

  @spec upload_form_image(%View{}, upload_entry()) ::
          String.t() | redirect_error()
  defp upload_form_image(%View{} = live, upload_entry) do
    upload(live, "#product-form", :image, upload_entry)
  end

  @spec form_upload_errors(%View{}, upload_entry()) :: [atom()]
  defp form_upload_errors(%View{} = live_view, upload_entry) do
    upload_errors(live_view, "#product-form", :image, upload_entry)
  end

  @spec form_list_item_value(%View{}, String.t()) :: String.t() | nil
  defp form_list_item_value(%View{} = live_view, text_filter) do
    list_item_value(live_view, "#product-form dl > div", text_filter)
  end
end
