defmodule CloudDbUiWeb.ProductTypeLiveTest do
  use CloudDbUiWeb.ConnCase

  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest
  import CloudDbUi.ProductsFixtures

  @type html_or_redirect() :: CloudDbUi.Type.html_or_redirect()

  describe "Index, a not-logged-in guest" do
    setup [:create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_log_in_page(live(conn, ~p"/product_types"))
      assert_redirect_to_log_in_page(live(conn, ~p"/product_types/new"))

      conn
      |> live(~p"/product_types/#{type}/edit")
      |> assert_redirect_to_log_in_page()
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user, :create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_main_page(live(conn, ~p"/product_types"))
      assert_redirect_to_main_page(live(conn, ~p"/product_types/new"))

      conn
      |> live(~p"/product_types/#{type}/edit")
      |> assert_redirect_to_main_page()
    end
  end

  describe "Index, an admin" do
    setup [:register_and_log_in_admin, :create_product_type]

    test "lists all product types", %{conn: conn, type: type} do
      non_assignable = product_type_fixture(%{assignable: false})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert(has_header?(index_live, "Listing product types"))
      assert(has_table_cell?(index_live, type.description))
      assert(has_element?(index_live, "#types-#{type.id}"))
      assert(has_element?(index_live, "#types-#{non_assignable.id}"))
    end

    test "saves a new product type", %{conn: conn, type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      refute(has_element?(index_live, "input#product_type_name"))

      click(index_live, "div.flex-none > a", "New product type")

      assert(has_element?(index_live, "input#product_type_name"))
      assert_patch(index_live, ~p"/product_types/new")
      assert_form_errors(index_live)
      assert_label_change(index_live)

      submit(index_live, "#product-type-form")

      assert_patch(index_live, ~p"/product_types")
      assert(has_flash?(index_live, :info, "Product type created"))
      # TODO: assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, nil, ["NEW_name", "NEWEST_desc"]))

      index_live
      |> has_table_row?("#types-#{type.id}", [type.name, type.description])
      |> assert()
    end

    test "updates a product type in listing", %{conn: conn, type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert(has_table_cell?(index_live, "Yes"))

      index_live
      |> click("#types-#{type.id} a", "Edit")
      |> assert_match("Edit product type ID #{type.id}")

      assert_patch(index_live, ~p"/product_types/#{type}/edit")
      assert_form_errors(index_live)
      assert_label_change(index_live)

      submit(
        index_live,
        "#product-type-form",
        %{product_type: %{assignable: false}}
      )

      assert_patch(index_live, ~p"/product_types")
      assert(has_flash?(index_live, :info, "Product type ID #{type.id} updat"))
      # TODO: assert_table_row_count(index_live, 1)
      refute(has_table_cell?(index_live, "Yes"))

      index_live
      |> has_table_row?("#types-#{type.id}", ["NEW_name", "NEWEST_desc"])
      |> assert()
    end

    test "deletes a product type with no products in listing",
         %{conn: conn, type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      click(index_live, "#types-#{type.id} a", "Delete")

      assert(has_flash?(index_live, :info, "leted product type ID #{type.id}"))
      refute(has_element?(index_live, "#types-#{type.id}"))
    end

    test "cannot delete a product type that has products of it in listing",
         %{conn: conn, type: type} do
      product_fixture(%{product_type: type})

      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      click(index_live, "#types-#{type.id} a", "Delete")

      assert(has_element?(index_live, "#types-#{type.id}"))
      assert(has_flash?(index_live, "Cannot delete a product type that is as"))
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_log_in_page(live(conn, ~p"/product_types/#{type}"))

      conn
      |> live(~p"/product_types/#{type}/show")
      |> assert_redirect_to_log_in_page()

      conn
      |> live(~p"/product_types/#{type}/show/edit")
      |> assert_redirect_to_log_in_page()
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_main_page(live(conn, ~p"/product_types/#{type}"))
      assert_redirect_to_main_page(live(conn, ~p"/product_types/#{type}/show"))

      conn
      |> live(~p"/product_types/#{type}/show/edit")
      |> assert_redirect_to_main_page()
    end
  end

  describe "Show, an admin" do
    setup [:register_and_log_in_admin, :create_product_type]

    test "displays a product type", %{conn: conn, type: type} do
      non_assignable = product_type_fixture(%{assignable: false})
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      assert(page_title(show_live) =~ "Show product type ID #{type.id}")
      assert(list_item_value(show_live, "Description") == type.description)

      {:ok, live, _html} = live(conn, ~p"/product_types/#{non_assignable}")

      assert(page_title(live) =~ "Show product type ID #{non_assignable.id}")
      assert(list_item_value(live, "Descriptio") == non_assignable.description)
    end

    test "updates a product_type within modal", %{conn: conn, type: type} do
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      assert(list_item_value(show_live, "Assignable to products") == "Yes")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product type ID #{type.id}")

      assert_patch(show_live, ~p"/product_types/#{type}/show/edit")
      assert_form_errors(show_live)
      assert_label_change(show_live)

      submit(
        show_live,
        "#product-type-form",
        %{product_type: %{assignable: false}}
      )

      assert_patch(show_live, ~p"/product_types/#{type}")
      assert(has_flash?(show_live, :info, "Product type ID #{type.id} updat"))
      assert(list_item_value(show_live, "Name") == "NEW_name")
      assert(list_item_value(show_live, "Description") == "NEWEST_desc")
      assert(list_item_value(show_live, "Assignable to products") == "No")
    end

    test "deletes a product type with no products",
         %{conn: conn, type: type} do
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn, ~p"/product_types")

      assert(has_flash?(index_live, :info, "leted product type ID #{type.id}"))
      refute(has_element?(index_live, "#types-#{type.id}"))
    end

    test "cannot delete a product type that has products of it",
         %{conn: conn, type: type} do
      product_fixture(%{product_type: type})

      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
      assert(has_flash?(show_live, "Cannot delete a product type that is as"))
    end
  end

  @spec assert_form_errors(%View{}) :: boolean()
  defp assert_form_errors(%View{} = lv) do
    assert(form_errors(lv, "#product-type-form") == [])
    assert_form_name_taken_errors(lv)

    change_form(lv, %{name: nil})

    assert(has_form_error?(lv, "#product-type-form", :name, "n&#39;t be blan"))

    change_form(lv, %{name: String.duplicate("i", 61)})

    lv
    |> has_form_error?("#product-type-form", :name, "at most 60 character(s)")
    |> assert()

    change_form(lv, %{name: "NEW_name"})

    assert(form_errors(lv, "#product-type-form", :name) == [])

    change_form(lv, %{description: String.duplicate("i", 201)})

    lv
    |> has_form_error?("#product-type-form", :description, "at most 200 chara")
    |> assert()

    change_form(lv, %{description: "NEWEST_desc"})

    assert(form_errors(lv, "#product-type-form") == [])
  end

  @spec assert_form_name_taken_errors(%View{}) :: boolean()
  defp assert_form_name_taken_errors(%View{} = lv) do
    other = product_type_fixture(%{name: "existING"})

    change_form(lv, %{name: "  " <> other.name <> " "})

    assert(has_form_error?(lv, "#product-type-form", :name, "eady been taken"))

    change_form(lv, %{name: "   " <> String.upcase(other.name) <> "  "})

    assert(has_form_error?(lv, "#product-type-form", :name, "eady been taken"))

    change_form(lv, %{name: " " <> String.downcase(other.name) <> "   "})

    assert(has_form_error?(lv, "#product-type-form", :name, "eady been taken"))
  end

  # Check that the `:name` and the `:description` labels display
  # character count.
  @spec assert_label_change(%View{}) :: boolean()
  defp assert_label_change(%View{} = live_view) do
    change_form(live_view, %{name: nil})

    assert(label_text(live_view, :name) == "Name")

    change_form(live_view, %{name: "NEW_name"})

    assert(label_text(live_view, :name) =~ "Name (8/60 character")

    change_form(live_view, %{description: nil})

    assert(label_text(live_view, :description) == "Description")

    change_form(live_view, %{description: "NEWEST_desc"})

    assert(label_text(live_view, :description) =~ "Description (11/200 charac")
  end

  # Should return a rendered `#product-type-form`.
  @spec change_form(%View{}, %{atom() => any()}) :: html_or_redirect()
  defp change_form(%View{} = live_view, type_data) do
    change(live_view, "#product-type-form", %{product_type: type_data})
  end
end
