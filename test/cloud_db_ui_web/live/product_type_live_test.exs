defmodule CloudDbUiWeb.ProductTypeLiveTest do
  use CloudDbUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import CloudDbUi.ProductsFixtures

  @create_attrs %{description: "some description", name: "some name"}
  @update_attrs %{description: "some new description", name: "some new name"}
  @invalid_attrs %{description: nil, name: nil}

  describe "Index (not logged in)" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert({:error, redirect} = live(conn, ~p"/product_types"))
      assert({:redirect, %{to: path, flash: flash}} = redirect)
      assert(path == ~p"/users/log_in")
      assert(%{"error" => "You must log in to access this page."} = flash)
    end
  end

  describe "Index (user)" do
    setup [:register_and_log_in_user]

    test "redirects if user is not logged in", %{conn: conn} do
      assert({:error, redirect} = live(conn, ~p"/product_types"))
      assert({:redirect, %{to: path, flash: flash}} = redirect)
      assert(path == ~p"/")
      assert(
        %{"error" => "Only an administrator may access this page."} = flash
      )
    end
  end

  describe "Index (admin)" do
    setup [:create_product_type, :register_and_log_in_admin]

    test "lists all product types", %{conn: conn, product_type: type} do
      {:ok, _index_live, html} = live(conn, ~p"/product_types")

      assert(html =~ "Listing product types")
      assert(html =~ type.description)
    end

    test "saves a new product type", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      index_live
      |> element("a", "New product type")
      |> render_click()
      |> Kernel.=~("New product type")
      |> assert()

      assert_patch(index_live, ~p"/product_types/new")

      index_live
      |> form("#product_type-form", product_type: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#product_type-form", product_type: @create_attrs)
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/product_types")

      html = render(index_live)

      assert(html =~ "Product type created successfully")
      assert(html =~ "some description")
    end

    test "updates a product type in listing",
         %{conn: conn, product_type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      index_live
      |> element("#product_types-#{type.id} a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit product type")
      |> assert()

      assert_patch(index_live, ~p"/product_types/#{type}/edit")

      index_live
      |> form("#product_type-form", product_type: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      index_live
      |> form("#product_type-form", product_type: @update_attrs)
      |> render_submit()
      |> assert()

      assert_patch(index_live, ~p"/product_types")

      html = render(index_live)

      assert(html =~ "Product type updated successfully")
      assert(html =~ "some new description")
    end

    test "deletes a product type in listing",
         %{conn: conn, product_type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      index_live
      |> element("#product_types-#{type.id} a", "Delete")
      |> render_click()
      |> assert()

      refute has_element?(index_live, "#product_types-#{type.id}")
    end
  end

  describe "Show (not logged in)" do
    setup [:create_product_type]

    test "redirects if user is not logged in",
         %{conn: conn, product_type: type} do
      assert({:error, redirect} = live(conn, ~p"/product_types/#{type}"))
      assert({:redirect, %{to: path, flash: flash}} = redirect)
      assert(path == ~p"/users/log_in")
      assert(%{"error" => "You must log in to access this page."} = flash)
    end
  end

  describe "Show (user)" do
    setup [:create_product_type, :register_and_log_in_user]

    test "redirects if user is not logged in",
         %{conn: conn, product_type: type} do
      assert({:error, redirect} = live(conn, ~p"/product_types/#{type}"))
      assert({:redirect, %{to: path, flash: flash}} = redirect)
      assert(path == ~p"/")
      assert(
        %{"error" => "Only an administrator may access this page."} = flash
      )
    end
  end

  describe "Show (admin)" do
    setup [:create_product_type, :register_and_log_in_admin]

    test "displays a product type", %{conn: conn, product_type: type} do
      {:ok, _show_live, html} = live(conn, ~p"/product_types/#{type}")

      assert(html =~ "Show product type")
      assert(html =~ type.description)
    end

    test "updates a product_type within modal",
         %{conn: conn, product_type: type} do
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      show_live
      |> element("a", "Edit")
      |> render_click()
      |> Kernel.=~("Edit product type")
      |> assert()

      assert_patch(show_live, ~p"/product_types/#{type}/show/edit")

      show_live
      |> form("#product_type-form", product_type: @invalid_attrs)
      |> render_change()
      |> Kernel.=~("can&#39;t be blank")
      |> assert()

      show_live
      |> form("#product_type-form", product_type: @update_attrs)
      |> render_submit()
      |> assert()

      assert_patch(show_live, ~p"/product_types/#{type}")

      html = render(show_live)

      assert(html =~ "Product type updated successfully")
      assert(html =~ "some new description")
    end
  end

  defp create_product_type(_), do: %{product_type: product_type_fixture()}
end
