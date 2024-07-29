defmodule CloudDbUiWeb.ProductLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.SubOrder
  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest
  import CloudDbUi.{ProductsFixtures, OrdersFixtures}

  @type redirect() :: CloudDbUi.Type.redirect()

  describe "Index, a not-logged-in guest" do
    setup [:create_product]

    test "lists only orderable products", %{conn: conn, product: product} do
      non_orderable = product_fixture(%{orderable: false})

      {:ok, index_live, html} = live(conn, ~p"/products")

      assert(html =~ "Listing products")
      assert(html =~ product.description)
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

    test "lists only orderable products", %{conn: conn, product: product} do
      non_orderable = product_fixture(%{orderable: false})

      {:ok, index_live, html} = live(conn, ~p"/products")

      assert(html =~ "Listing products")
      assert(html =~ product.description)
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
      order_fixture(%{user_id: user.id})

      {:ok, live, _html} = live(conn, ~p"/products")

      order_product(live, product, 555)

      assert(has_flash?(live, :info, "Added 555 pieces of"))
    end

    test "updates a sub-order of an unpaid order by ordering a valid quantity",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user_id: user.id})

      suborder_fixture(%{order_id: order.id, product_id: product.id})

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
      order = order_fixture(%{user_id: user.id})

      suborder =
        suborder_fixture(%{order_id: order.id, product_id: product.id})

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

    setup [
      :create_unassignable_product_type,
      :create_product,
      :register_and_log_in_admin,
    ]

    test "lists all products", %{conn: conn, product: product} do
      non_orderable = product_fixture(%{orderable: false})

      {:ok, index_live, html} = live(conn, ~p"/products")

      assert(html =~ "Listing products")
      assert(html =~ product.description)
      assert(has_element?(index_live, "th", "Type ID"))
      assert(has_element?(index_live, "th", "Orderable"))
      assert(has_element?(index_live, "#products-#{product.id}"))
      assert(has_element?(index_live, "#products-#{non_orderable.id}"))
    end

    test "saves a new product", %{conn: conn} do
      assignable = product_type_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/products")

      refute(has_element?(index_live, "input#product_name"))

      click(index_live, "div.flex-none > a", "New product")

      assert(has_element?(index_live, "input#product_name"))
      assert_patch(index_live, ~p"/products/new")
      refute(render(index_live) =~ "can&#39;t be blank")
      assert(change_form(index_live, %{name: nil}) =~ "can&#39;t be blank")

      index_live
      |> change_form(%{name: "some name", unit_price: nil})
      |> assert_match("can&#39;t be blank")

      index_live
      |> change_form(%{unit_price: "123.4", product_type_id: nil})
      |> assert_match("can&#39;t be blank")

      index_live
      |> change_form(%{product_type_id: assignable.id})
      |> refute_match("can&#39;t be blank")

      submit(index_live, "#product-form", %{product: %{description: "nEWEst"}})

      assert_patch(index_live, ~p"/products")
      assert(has_flash?(index_live, :info, "Product created successfully"))
      assert(render(index_live) =~ "nEWEst")
    end

    test "cannot save a new product when all types are not assignable",
         %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      refute(has_element?(index_live, "input#product_name"))

      click(index_live, "a", "New product")

      assert(has_element?(index_live, "input#product_name"))
      assert_patch(index_live, ~p"/products/new")
      refute(has_element?(index_live, "select#product_product_type_id"))
      assert(render(index_live) =~ "unable to set product type: no")

      submit(
        index_live,
        "#product-form",
        %{product: %{name: "some name", unit_price: "9.00"}}
      )

      assert(has_element?(index_live, "input#product_name"))
      assert(has_flash?(index_live, "Product type can&#39;t be blank"))
    end

    test "updates a product in listing", %{conn: conn, product: product} do
      assignable = product_type_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/products")

      index_live
      |> click("#products-#{product.id} a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(index_live, ~p"/products/#{product}/edit")
      refute(render(index_live) =~ "can&#39;t be blank")
      assert(change_form(index_live, %{name: nil}) =~ "can&#39;t be blank")

      assert(change_form(index_live, %{name: nil}) =~ "can&#39;t be blank")
      refute(change_form(index_live, %{name: "n"}) =~ "can&#39;t be blank")
      assert(change_form(index_live, %{unit_price: nil}) =~ "can&#39;t be bla")
      assert(change_form(index_live, %{unit_price: "a"}) =~ "is invalid")
      assert(change_form(index_live, %{unit_price: -1}) =~ "must not be negat")
      assert(change_form(index_live, %{unit_price: "0.001"}) =~ "nvalid forma")
      refute(change_form(index_live, %{unit_price: 10}) =~ "can&#39;t be blan")

      submit(
        index_live,
        "#product-form",
        %{product: %{description: "nEWEst", product_type_id: assignable.id}}
      )

      assert_patch(index_live, ~p"/products")
      assert(has_flash?(index_live, :info, "Product ID #{product.id} updated"))
      assert(render(index_live) =~ "nEWEst")
    end

    test "cannot change a product type when all types are not assignable",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      index_live
      |> click("#products-#{product.id} a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(index_live, ~p"/products/#{product}/edit")
      refute(has_element?(index_live, "select#product_product_type_id"))

      index_live
      |> render()
      |> tap(fn rendered ->
        refute(rendered =~ "can&#39;t be blank")
        assert(rendered =~ "Unable to change product type: no")
      end)

      assert(change_form(index_live, %{name: nil}) =~ "can&#39;t be blank")

      index_live
      |> change_form(%{name: "some name", unit_price: nil})
      |> assert_match("can&#39;t be blank")

      index_live
      |> change_form(%{unit_price: "50"})
      |> refute_match("can&#39;t be blank")

      submit(index_live, "#product-form", %{product: %{description: "nEWEst"}})

      assert_patch(index_live, ~p"/products")
      assert(has_flash?(index_live, :info, "Product ID #{product.id} updated"))
      assert(render(index_live) =~ "nEWEst")
    end

    test "deletes a product that has no orders",
         %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      click(index_live, "#products-#{product.id} a", "Delete")

      assert(has_flash?(index_live, :info, "Deleted product ID #{product.id}"))
      refute(has_element?(index_live, "#products-#{product.id}"))
    end

    test "cannot delete a product that has any orders of it",
         %{conn: conn, product: product} do
      suborder_fixture(%{product_id: product.id})

      {:ok, index_live, _html} = live(conn, ~p"/products")

      click(index_live, "#products-#{product.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete a product that"))
      assert(has_element?(index_live, "#products-#{product.id}"))
    end

    test "cannot order a product", %{conn: conn, product: product} do
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

    test "can view an orderable product", %{conn: conn, product: product} do
      {:ok, show_live, html} = live(conn, ~p"/products/#{product}")

      assert(html =~ "Show product ID #{product.id}")
      assert(html =~ product.description)
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

    test "can view an orderable product", %{conn: conn, product: product} do
      {:ok, show_live, html} = live(conn, ~p"/products/#{product}")

      assert(html =~ "Show product ID #{product.id}")
      assert(html =~ product.description)
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
      order_fixture(%{user_id: user.id})

      {:ok, live, _html} = live(conn, ~p"/products/#{product}")

      order_product(live, product, 555)

      assert(has_flash?(live, :info, "Added 555 pieces of"))
    end

    test "updates a sub-order of an unpaid order by ordering a valid quantity",
         %{conn: conn, product: product, user: user} do
      order = order_fixture(%{user_id: user.id})

      suborder_fixture(%{order_id: order.id, product_id: product.id})

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
      order = order_fixture(%{user_id: user.id})

      suborder =
        suborder_fixture(%{order_id: order.id, product_id: product.id})

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
    setup [
      :register_and_log_in_admin,
      :create_unassignable_product_type,
      :create_product
    ]

    test "can view any product", %{conn: conn, product: product} do
      {:ok, show_live, html} = live(conn, ~p"/products/#{product}")

      assert(html =~ "Show product ID #{product.id}")
      assert(html =~ product.description)
      assert(has_element?(show_live, "dt", "Type ID"))

      non_orderable = product_fixture(%{orderable: false, description: "dESc"})
      {:ok, show_live, html} = live(conn, ~p"/products/#{non_orderable}")

      assert(html =~ "Show product ID #{non_orderable.id}")
      assert(html =~ non_orderable.description)
      assert(has_element?(show_live, "dt", "Type ID"))
    end

    test "updates a product within modal", %{conn: conn, product: product} do
      assignable = product_type_fixture()
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(show_live, ~p"/products/#{product}/show/edit")
      assert(has_element?(show_live, "select#product_product_type_id"))
      refute(render(show_live) =~ "can&#39;t be blank")
      assert(change_form(show_live, %{name: nil}) =~ "can&#39;t be blank")
      refute(change_form(show_live, %{name: "n"}) =~ "can&#39;t be blank")
      assert(change_form(show_live, %{unit_price: nil}) =~ "can&#39;t be blan")
      assert(change_form(show_live, %{unit_price: "a"}) =~ "is invalid")
      assert(change_form(show_live, %{unit_price: -1}) =~ "must not be negati")
      assert(change_form(show_live, %{unit_price: "0.001"}) =~ "invalid forma")
      refute(change_form(show_live, %{unit_price: 10}) =~ "can&#39;t be blank")

      submit(
        show_live,
        "#product-form",
        %{product: %{description: "nEWEst", product_type_id: assignable.id}}
      )

      assert_patch(show_live, ~p"/products/#{product}")
      assert(has_flash?(show_live, :info, "Product ID #{product.id} updated"))
      assert(render(show_live) =~ "nEWEst")
    end

    test "cannot change a product type when all types are not assignable",
         %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product ID #{product.id}")

      assert_patch(show_live, ~p"/products/#{product}/show/edit")
      refute(has_element?(show_live, "select#product_product_type_id"))

      show_live
      |> render()
      |> tap(fn rendered ->
        refute(rendered =~ "can&#39;t be blank")
        assert(rendered =~ "Unable to change product type: no")
      end)

      assert(change_form(show_live, %{name: nil}) =~ "can&#39;t be blank")

      show_live
      |> change_form(%{name: "some name", unit_price: nil})
      |> assert_match("can&#39;t be blank")

      show_live
      |> change_form(%{unit_price: "50"})
      |> refute_match("can&#39;t be blank")

      submit(show_live, "#product-form", %{product: %{description: "nEWEst"}})

      assert_patch(show_live, ~p"/products/#{product}")
      assert(has_flash?(show_live, :info, "Product ID #{product.id} updated"))
      assert(render(show_live) =~ "nEWEst")
    end

    test "deletes a product that has no orders",
         %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn)

      assert(has_flash?(index_live, :info, "Deleted product ID #{product.id}"))
      refute(has_element?(index_live, "#products-#{product.id}"))
    end

    test "cannot delete a product that has any orders of it",
         %{conn: conn, product: product} do
      suborder_fixture(%{product_id: product.id})

      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
      assert(has_flash?(show_live, "Cannot delete a product that has"))
    end
  end

  @spec assert_order_invalid_quantity(%View{}, %Product{}) :: boolean()
  defp assert_order_invalid_quantity(%View{} = live_view, product) do
    order_product(live_view, product, nil)

    assert(has_flash?(live_view, "Invalid quantity."))

    order_product(live_view, product, 0)

    assert(has_flash?(live_view, "Cannot order fewer than one piece"))

    order_product(live_view, product, SubOrder.quantity_limit() + 1)

    assert(has_flash?(live_view, "Cannot order more than"))
  end

  # Make the form send a `phx-submit` event with `product.id`
  # and `quantity`.
  @spec order_product(%View{}, %Product{}, any()) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp order_product(%View{} = index_live, product, quantity) do
    submit(
      index_live,
      "#order-form-#{product.id}",
      %{sub_order: %{quantity: quantity}}
    )
  end

  # Returns a rendered `#product-form`.
  @spec change_form(%View{}, %{atom() => any()}) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_form(%View{} = live_view, product_data) do
    change(live_view, "#product-form", %{product: product_data})
  end
end
