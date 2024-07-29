defmodule CloudDbUiWeb.ProductTypeLiveTest do
  use CloudDbUiWeb.ConnCase

  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest
  import CloudDbUi.ProductsFixtures

  @type redirect() :: CloudDbUi.Type.redirect()

  @create_attrs %{description: "some description", name: "some name"}
  @update_attrs %{description: "some new description", name: "some new name"}

  # TODO: test taken names

  describe "Index, a not-logged-in guest" do
    test "gets redirected away", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/product_types")

      assert(path == ~p"/users/log_in")
      assert(flash["error"] =~ "You must log in to access this page.")
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user]

    test "gets redirected away", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/product_types")

      assert(path == ~p"/")
      assert(flash["error"] =~ "Only an administrator may access")
    end
  end

  describe "Index, an admin" do
    setup [:create_product_type, :register_and_log_in_admin]

    test "lists all product types", %{conn: conn, type: type} do
      non_assignable = product_type_fixture(%{assignable: false})
      {:ok, index_live, html} = live(conn, ~p"/product_types")

      assert(html =~ "Listing product types")
      assert(html =~ type.description)
      assert(has_element?(index_live, "#types-#{non_assignable.id}"))
    end

    test "saves a new product type", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      refute(has_element?(index_live, "input#product_type_name"))

      click(index_live, "div.flex-none > a", "New product type")

      assert(has_element?(index_live, "input#product_type_name"))
      assert_patch(index_live, ~p"/product_types/new")
      assert(change_name(index_live, nil) =~ "can&#39;t be blank")

      change(index_live, "#product-type-form", %{product_type: @create_attrs})
      submit(index_live, "#product-type-form")

      assert_patch(index_live, ~p"/product_types")
      assert(has_flash?(index_live, :info, "Product type created"))
      assert(render(index_live) =~ "some description")
    end

    test "updates a product type in listing",
         %{conn: conn, type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      index_live
      |> click("#types-#{type.id} a", "Edit")
      |> assert_match("Edit product type ID #{type.id}")

      assert_patch(index_live, ~p"/product_types/#{type}/edit")
      assert(change_name(index_live, nil) =~ "can&#39;t be blank")

      change(index_live, "#product-type-form", %{product_type: @update_attrs})
      submit(index_live, "#product-type-form")

      assert_patch(index_live, ~p"/product_types")

      assert(has_flash?(index_live, :info, "Product type ID #{type.id} updat"))
      assert(render(index_live) =~ "some new description")
    end

    test "deletes a product type with no products in listing",
         %{conn: conn, type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      click(index_live, "#types-#{type.id} a", "Delete")

      refute(has_element?(index_live, "#types-#{type.id}"))
    end

    test "cannot delete a product type that has products of it in listing",
         %{conn: conn, type: type} do
      product_fixture(%{product_type_id: type.id})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      click(index_live, "#types-#{type.id} a", "Delete")

      assert(has_element?(index_live, "#types-#{type.id}"))
      assert(has_flash?(index_live, "Cannot delete a product type that is as"))
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/product_types/#{type}")

      assert(path == ~p"/users/log_in")
      assert(flash["error"] =~ "You must log in to access this page.")
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/product_types/#{type}")

      assert(path == ~p"/")
      assert(flash["error"] =~ "Only an administrator may access")
    end
  end

  describe "Show, an admin" do
    setup [:register_and_log_in_admin, :create_product_type]

    test "displays a product type", %{conn: conn, type: type} do
      non_assignable = product_type_fixture(%{assignable: false})
      {:ok, _show_live, html} = live(conn, ~p"/product_types/#{type}")

      assert(html =~ "Show product type ID #{type.id}")
      assert(html =~ type.description)

      {:ok, _live, html} = live(conn, ~p"/product_types/#{non_assignable}")

      assert(html =~ "Show product type ID #{non_assignable.id}")
      assert(html =~ non_assignable.description)
    end

    test "updates a product_type within modal",
         %{conn: conn, type: type} do
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product type ID #{type.id}")

      assert_patch(show_live, ~p"/product_types/#{type}/show/edit")
      assert(change_name(show_live, nil) =~ "can&#39;t be blank")

      change(show_live, "#product-type-form", %{product_type: @update_attrs})
      submit(show_live, "#product-type-form")

      assert_patch(show_live, ~p"/product_types/#{type}")
      assert(has_flash?(show_live, :info, "Product type ID #{type.id} updat"))
      assert(render(show_live) =~ "some new description")
    end

    test "deletes a product type with no products",
         %{conn: conn, type: type} do
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn)

      assert(has_flash?(index_live, :info, "leted product type ID #{type.id}"))
      refute(has_element?(index_live, "#types-#{type.id}"))
    end

    test "cannot delete a product type that has products of it",
         %{conn: conn, type: type} do
      product_fixture(%{product_type_id: type.id})
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
      assert(has_flash?(show_live, "Cannot delete a product type that is as"))
    end
  end

  # Returns a rendered `#product-type-form`.
  @spec change_name(%View{}, %{atom() => any()}) ::
          String.t() | {:error, {:redirect, redirect()}}
  defp change_name(%View{} = live_view, name) do
    change(live_view, "#product-type-form", %{product_type: %{name: name}})
  end
end
