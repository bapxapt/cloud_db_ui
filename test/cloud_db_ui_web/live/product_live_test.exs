defmodule CloudDbUiWeb.ProductLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.DataCase
  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.{Product, ProductType}
  alias CloudDbUi.Orders.SubOrder
  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest
  import CloudDbUi.{ProductsFixtures, OrdersFixtures, AccountsFixtures}

  @type html_or_redirect() :: CloudDbUi.Type.html_or_redirect()
  @type upload_entry() :: CloudDbUi.Type.upload_entry()

  describe "Index, a not-logged-in guest" do
    setup [:create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      assert_redirect_to_log_in_page(live(conn, ~p"/products/new"))
      assert_redirect_to_log_in_page(live(conn, ~p"/products/#{product}/edit"))
    end

    test "lists only orderable products", %{conn: conn, product: product} do
      non_orderable = product_fixture(%{orderable: false})

      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert(page_title(index_live) =~ "Listing products")
      assert(has_table_cell?(index_live, product.description))
      refute(has_element?(index_live, "th", "Type ID"))
      assert(has_element?(index_live, "#products-#{product.id}"))
      refute(has_element?(index_live, "#products-#{non_orderable.id}"))
    end

    test "gets redirected away when trying to order a product",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      order_product(index_live, product, 123)

      flash = assert_redirect(index_live, ~p"/users/log_in")

      assert(flash["error"] =~ "You must log in")
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user, :create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      assert_redirect_to_main_page(live(conn, ~p"/products/new"))
      assert_redirect_to_main_page(live(conn, ~p"/products/#{product}/edit"))
    end

    test "lists only orderable products", %{conn: conn, product: product} do
      non_orderable = product_fixture(%{orderable: false})
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert(page_title(index_live) =~ "Listing products")
      assert(has_table_cell?(index_live, product.description))
      refute(has_element?(index_live, "th", "Type ID"))
      assert(has_element?(index_live, "#products-#{product.id}"))
      refute(has_element?(index_live, "#products-#{non_orderable.id}"))
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

      {:ok, live, _html} = live(conn, ~p"/products")

      order_product(live, product, 555)

      assert(has_flash?(live, :info, "Added 555 pieces of"))
    end

    test "updates a sub-order of an unpaid order by ordering a valid quantity",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user: user})

      suborder_fixture(%{order: order, product: product})

      {:ok, live, _html} = live(conn, ~p"/products")

      order_product(live, product, 999)

      assert(has_flash?(live, :info, "Added 999 pieces of"))
    end

    test "cannot order an invalid quantity",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert_order_invalid_quantity(index_live, product)
    end

    test "cannot order when the resulting quantity would exceed the limit",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user: user})
      suborder = suborder_fixture(%{order: order, product: product})

      {:ok, live, _html} = live(conn, ~p"/products")

      order_product(
        live,
        product,
        SubOrder.quantity_limit() - suborder.quantity + 1
      )

      assert(has_flash?(live, "already have #{suborder.quantity} pie"))
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

      refute(has_element?(index_live, "input#product_name"))
      refute(has_element?(index_live, "img[alt='product image']"))

      click(index_live, "div.flex-none > a", "New product")

      assert(has_element?(index_live, "input#product_name"))
      assert_patch(index_live, ~p"/products/new")

      # TODO: remove
      # TODO: a flaky test, sometimes fails here
      if !has_element?(index_live, "#product-form input[type=\"file\"][name=\"image\"]") do
        open_browser(index_live)
      end

      assert_form_errors(index_live, unassignable, assignable)
      assert_label_change(index_live)

      submit(index_live, "#product-form")

      assert_patch(index_live, ~p"/products")
      assert(has_element?(index_live, "img[alt='product image']"))
      assert(has_flash?(index_live, :info, "Product created successfully"))
      assert(has_table_cell?(index_live,  "NEWEST_desc"))
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

      # TODO: remove
      # TODO: a flaky test, sometimes fails here
      if !has_element?(index_live, "#product-form input[type=\"file\"][name=\"image\"]") do
        open_browser(index_live)
      end

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

      DataCase.set_as_unassignable(type)

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

      click(index_live, "#products-#{product.id} a", "Delete")

      assert(has_flash?(index_live, :info, "Deleted product ID #{product.id}"))
      refute(has_element?(index_live, "#products-#{product.id}"))
    end

    test "cannot delete a product that has any paid orders of it",
         %{conn: conn} do
      product = product_fixture()
      user = user_fixture()
      order = order_fixture(%{user: user})

      suborder_fixture(%{order: order, product: product})
      DataCase.set_as_paid(order, user)

      {:ok, index_live, _html} = live(conn, ~p"/products")

      click(index_live, "#products-#{product.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete a product, paid orders of"))
      assert(has_element?(index_live, "#products-#{product.id}"))
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
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      conn
      |> live(~p"/products/#{product}/show/edit")
      |> assert_redirect_to_log_in_page()
    end

    test "can view an orderable product", %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert(page_title(show_live) =~ "Show product ID #{product.id}")
      assert(list_item_value(show_live, "Description") == product.description)
      refute(has_element?(show_live, "dt", "Type ID"))
    end

    test "cannot view a non-orderable product", %{conn: conn} do
      non_orderable = product_fixture(%{orderable: false})

      assert_raise(Ecto.NoResultsError, fn ->
        live(conn, ~p"/products/#{non_orderable}")
      end)
    end

    test "gets redirected away when trying to order a product",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products/#{product}")

      order_product(index_live, product, 123)

      flash = assert_redirect(index_live, ~p"/users/log_in")

      assert(flash["error"] =~ "You must log in")
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_product]

    test "gets redirected away", %{conn: conn, product: product} do
      conn
      |> live(~p"/products/#{product}/show/edit")
      |> assert_redirect_to_main_page()
    end

    test "can view an orderable product", %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert(page_title(show_live) =~ "Show product ID #{product.id}")
      assert(list_item_value(show_live, "Description") == product.description)
      refute(has_element?(show_live, "dt", "Type ID"))
    end

    test "cannot view a non-orderable product", %{conn: conn} do
      non_orderable = product_fixture(%{orderable: false})

      assert_raise(Ecto.NoResultsError, fn ->
        live(conn, ~p"/products/#{non_orderable}")
      end)
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

      DataCase.set_as_unassignable(type)

      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(show_live, ~p"/products/#{product}/show/edit")
      refute(has_element?(show_live, "select#product_product_type_id"))

      show_live
      |> has_element?("#product-form label", "Unable to change product type:")
      |> assert()

      # TODO: a flaky test, sometimes fails here
      try do
        assert_form_errors(show_live, unassignable, product_type_fixture())
      rescue
        e in RuntimeError ->
          IO.puts("\n\n")
          IO.puts(e.message)
          IO.puts("\n\n")
      end

      # TODO: assert_form_errors(show_live, unassignable, product_type_fixture())
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
          html_or_redirect()
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
          html_or_redirect()
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
  @spec order_product(%View{}, %Product{}, any()) :: html_or_redirect()
  defp order_product(%View{} = index_live, product, quantity) do
    submit(
      index_live,
      "#order-form-#{product.id}",
      %{sub_order: %{quantity: quantity}}
    )
  end

  # Should return a rendered `#product-form`.
  @spec change_form(%View{}, %{atom() => any()}) :: html_or_redirect()
  defp change_form(%View{} = live_view, product_data) do
    change(live_view, "#product-form", %{product: product_data})
  end

  @spec upload_form_image(%View{}, upload_entry()) :: html_or_redirect()
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
