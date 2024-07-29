defmodule CloudDbUiWeb.ProductLiveTest do
  use CloudDbUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import CloudDbUi.ProductsFixtures

  @create_attrs %{
    description: "some description",
    image: "some image",
    name: "some name",
    unit_price: 120.5
  }

  @update_attrs %{
    description: "some updated description",
    image: "some updated image",
    name: "some updated name",
    unit_price: 456.7
  }

  @invalid_attrs %{description: nil, image: nil, name: nil, unit_price: nil}

  describe "Index (not logged in)" do
    setup [:create_product]

    test "lists all products", %{conn: conn, product: product} do
      {:ok, index_live, html} = live(conn, ~p"/products")

      assert(html =~ "Listing products")
      assert(html =~ product.description)
      refute(has_element?(index_live, "th", "Type ID"))
      refute(has_element?(index_live, "button", "New product"))

      index_live
      |> element("#products-#{product.id} input[name=\"quantity\"]")
      |> has_element?()
      |> refute()

      index_live
      |> has_element?("#products-#{product.id} button", "Order")
      |> refute()

      refute(has_element?(index_live, "#products-#{product.id} a", "Edit"))
      refute(has_element?(index_live, "#products-#{product.id} a", "Delete"))
    end
  end

  describe "Index (user)" do
    setup [:create_product, :register_and_log_in_user]

    test "lists all products", %{conn: conn, product: product} do
      {:ok, index_live, html} = live(conn, ~p"/products")

      assert(html =~ "Listing products")
      assert(html =~ product.description)
      refute(has_element?(index_live, "th", "Type ID"))
      refute(has_element?(index_live, "button", "New product"))

      index_live
      |> element("#products-#{product.id} input[name=\"quantity\"]")
      |> has_element?()
      |> assert()

      index_live
      |> has_element?("#products-#{product.id} button", "Order")
      |> assert()

      refute(has_element?(index_live, "#products-#{product.id} a", "Edit"))
      refute(has_element?(index_live, "#products-#{product.id} a", "Delete"))
    end

    test "creates an order with valid quantity",
         %{conn: conn, product: product} do
      # TODO: set quantity, press the "Order" button
      # TODO: check order existence
      # TODO: element (flash with "Created order")
    end

    test "cannot create an order with invalid quantity",
         %{conn: conn, product: product} do
      # TODO: set quantity, press the "Order" button
      # TODO: check order existence
      # TODO: element (flash with "Created order")
    end
  end

  describe "Index (admin)" do
    setup [:create_product, :register_and_log_in_admin]

    test "lists all products", %{conn: conn, product: product} do
      {:ok, index_live, html} = live(conn, ~p"/products")

      assert(html =~ "Listing products")
      assert(html =~ product.description)
      assert(has_element?(index_live, "th", "Type ID"))
      assert(has_element?(index_live, "button", "New product"))

      index_live
      |> element("#products-#{product.id} input[name=\"quantity\"]")
      |> has_element?()
      |> refute()

      index_live
      |> has_element?("#products-#{product.id} button", "Order")
      |> refute()

      assert(has_element?(index_live, "#products-#{product.id} a", "Edit"))
      assert(has_element?(index_live, "#products-#{product.id} a", "Delete"))
    end

    test "saves a new product", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      index_live
      |> element("a", "New product")
      |> render_click()
      |> Kernel.=~("New product")
      |> assert()

      assert_patch(index_live, ~p"/products/new")

      index_live
      |> form("#product-form", product: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#product-form", product: @create_attrs)
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/products")

      html = render(index_live)

      assert(html =~ "Product created successfully")
      assert(html =~ "some description")
    end

    test "updates a product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      index_live
      |> element("#products-#{product.id} a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit product")
      |> assert()

      assert_patch(index_live, ~p"/products/#{product}/edit")

      index_live
      |> form("#product-form", product: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#product-form", product: @update_attrs)
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/products")

      html = render(index_live)

      assert(html =~ "Product updated successfully")
      assert(html =~ "some updated description")
    end

    test "deletes a product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      index_live
      |> element("#products-#{product.id} a", "Delete")
      |> render_click()
      |> assert()

      refute(has_element?(index_live, "#products-#{product.id}"))
    end
  end

  describe "Show (not logged in)" do
    setup [:create_product]

    test "displays a product", %{conn: conn, product: product} do
      {:ok, show_live, html} = live(conn, ~p"/products/#{product}")

      assert(html =~ "Show product")
      assert(html =~ product.description)
      refute(has_element?(show_live, "button", "Edit product"))
      refute(has_element?(show_live, "dt", "Type ID"))
    end

    test "correctly shows a 404 page if the product does not exist",
         %{conn: conn, product: product} do
      {:ok, show_live, html} = live(conn, ~p"/products/42")

      # TODO:
      assert(html =~ "Listing products")
      assert(html =~ product.description)
      # TODO: assert_patch(show_live)?
    end
  end

  describe "Show (user)" do
    setup [:create_product, :register_and_log_in_user]

    test "displays a product", %{conn: conn, product: product} do
      {:ok, show_live, html} = live(conn, ~p"/products/#{product}")

      assert(html =~ "Show product")
      assert(html =~ product.description)
      refute(has_element?(show_live, "button", "Edit product"))
      refute(has_element?(show_live, "dt", "Type ID"))
    end
  end

  describe "Show (admin)" do
    setup [:create_product, :register_and_log_in_admin]

    test "displays a product", %{conn: conn, product: product} do
      {:ok, show_live, html} = live(conn, ~p"/products/#{product}")

      assert(html =~ "Show product")
      assert(html =~ product.description)
      assert(has_element?(show_live, "button", "Edit product"))
      assert(has_element?(show_live, "dt", "Type ID"))
    end

    test "updates a product within modal", %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      show_live
      |> element("a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit product")
      |> assert()

      assert_patch(show_live, ~p"/products/#{product}/show/edit")

      show_live
      |> form("#product-form", product: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      show_live
      |> form("#product-form", product: @update_attrs)
      |> render_submit()
      |> assert()

      assert_patch(show_live, ~p"/products/#{product}")

      html = render(show_live)

      assert(html =~ "Product updated successfully")
      assert(html =~ "some updated description")
    end
  end

  defp create_product(_context), do: %{product: product_fixture()}
end
