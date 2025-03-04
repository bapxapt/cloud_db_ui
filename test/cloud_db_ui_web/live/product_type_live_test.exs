defmodule CloudDbUiWeb.ProductTypeLiveTest do
  use CloudDbUiWeb.ConnCase

  import CloudDbUi.ProductsFixtures
  import Phoenix.LiveViewTest

  alias CloudDbUi.DataCase
  alias Phoenix.LiveViewTest.View

  @type params() :: CloudDbUi.Type.params()
  @type redirect_error() :: CloudDbUi.Type.redirect_error()

  describe "Index, a not-logged-in guest" do
    setup [:create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_log_in_page(conn, ~p"/product_types")
      assert_redirect_to_log_in_page(conn, ~p"/product_types/new")
      assert_redirect_to_log_in_page(conn, ~p"/product_types/#{type}/edit")
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user, :create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_main_page(conn, ~p"/product_types")
      assert_redirect_to_main_page(conn, ~p"/product_types/new")
      assert_redirect_to_main_page(conn, ~p"/product_types/#{type}/edit")
    end
  end

  describe "Index, an admin" do
    setup [:register_and_log_in_admin, :create_product_type]

    test "lists all product types", %{conn: conn, type: type} do
      unassignable = product_type_fixture(%{assignable: false})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert(has_header?(index_live, "Listing product types"))
      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#types", type, [:id, :name]))
      assert(has_table_row?(index_live, "#types", unassignable, [:id, :name]))
    end

    test "saves a new product type", %{conn: conn, type: type} do
      other_type = product_type_fixture(%{name: "TAKEN_"})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 2)
      refute(has_element?(index_live, "input#product_type_name"))

      click(index_live, "div.flex-none > a", "New product type")

      assert(has_element?(index_live, "input#product_type_name"))
      assert_patch(index_live, ~p"/product_types/new")
      assert_form_errors(index_live, other_type.name)
      assert_label_change(index_live)

      submit(index_live, "#product-type-form")

      assert_patch(index_live, ~p"/product_types")
      assert(has_flash?(index_live, :info, "Product type created"))
      assert(String.starts_with?(type.name, "Type_"))
      assert(type.description == "some description")
      assert(has_table_row?(index_live, "#types", type, [:name, :description]))
      # There were only two rows, this is the newly-created one.
      assert(has_table_row?(index_live, nil, ["NEW_name", "NEWEST_desc"]))
      assert_table_row_count(index_live, 3)
    end

    test "updates a product type in listing", %{conn: conn, type: type} do
      other_type = product_type_fixture(%{name: "TAKEN_", assignable: false})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert(has_table_cell?(index_live, "Yes"))
      assert_table_row_count(index_live, 2)

      index_live
      |> click("#types-#{type.id} a", "Edit")
      |> assert_match("Edit product type ID #{type.id}")

      assert_patch(index_live, ~p"/product_types/#{type}/edit")
      assert_form_errors(index_live, other_type.name)
      assert_label_change(index_live)

      submit(
        index_live,
        "#product-type-form",
        %{product_type: %{assignable: false}}
      )

      assert_patch(index_live, ~p"/product_types")
      assert(has_flash?(index_live, :info, "Product type ID #{type.id} updat"))
      assert_table_row_count(index_live, 2)
      refute(has_table_cell?(index_live, "Yes"))

      index_live
      |> has_table_row?("#types-#{type.id}", ["NEW_name", "NEWEST_desc"])
      |> assert()
    end

    test "deletes a product type with no products in listing",
         %{conn: conn, type: type} do
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 1)

      click(index_live, "#types-#{type.id} a", "Delete")

      assert(has_flash?(index_live, :info, "leted product type ID #{type.id}"))
      refute(has_element?(index_live, "#types-#{type.id}"))
      assert_table_row_count(index_live, 0)
    end

    test "cannot delete a product type that has products of it in listing",
         %{conn: conn, type: type} do
      product_fixture(%{product_type: type})

      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 1)

      click(index_live, "#types-#{type.id} a", "Delete")

      assert(has_element?(index_live, "#types-#{type.id}"))
      assert(has_flash?(index_live, "Cannot delete a product type that is as"))
      assert_table_row_count(index_live, 1)
    end

    test "filters product types by the name", %{conn: conn, type: type} do
      other_type = product_type_fixture(%{name: "Some type"})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 2)

      filter(index_live, 0, "¢")

      assert_table_row_count(index_live, 0)

      filter(index_live, 0, String.upcase(type.name))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#types", type, [:id, :name]))

      filter(index_live, 0, String.upcase(other_type.name))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#types", other_type, [:id, :name]))
      assert_filter_form_errors(index_live, 0, "text")

      assert_filter_param_handling(
        conn,
        "product_types",
        0,
        :name_trimmed,
        :ilike
      )
    end

    test "filters product types by the description",
         %{conn: conn, type: type} do
      other_type = product_type_fixture(%{description: "Other description"})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 2)

      filter(index_live, 1, "¢")

      assert_table_row_count(index_live, 0)

      filter(index_live, 1, String.upcase(type.description))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#types", type, [:id, :description]))

      filter(index_live, 1, String.upcase(other_type.description))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#types", other_type, [:id, :name]))
      assert_filter_form_errors(index_live, 1, "text")

      assert_filter_param_handling(
        conn,
        "product_types",
        1,
        :description_trimmed,
        :ilike
      )
    end

    test "filters product types by \"Created from\"",
         %{conn: conn, type: type} do
      other = product_type_fixture()

      DataCase.update_inserted_at(type, "2020-02-15 15:00:00Z")
      DataCase.update_inserted_at(other, "2020-02-15 10:00:00Z")

      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 2)

      filter(index_live, 2, "2020-02-15 10:00")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#types", type, [:id, :name]))
      assert(has_table_row?(index_live, "#types", other, [:id, :name]))

      filter(index_live, 2, "2020-02-15 10:01")

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#types", type, [:id, :name]))
      refute(has_table_row?(index_live, "#types", other, [:id, :name]))

      filter(index_live, 2, "2020-02-15 15:01")

      assert_table_row_count(index_live, 0)
      refute(has_table_row?(index_live, "#types", type, [:id, :name]))
      refute(has_table_row?(index_live, "#types", other, [:id, :name]))
      assert_filter_form_errors(index_live, 2, 3, "datetime-local")
      assert_filter_param_handling(conn, "product_types", 2, :inserted_at, :>=)
    end

    test "filters product types by \"Created to\"",
         %{conn: conn, type: type} do
      other = product_type_fixture()

      DataCase.update_inserted_at(type, "2020-02-15 15:00:00Z")
      DataCase.update_inserted_at(other, "2020-02-15 10:00:00Z")

      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 2)

      filter(index_live, 3, "2020-02-15 15:00")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#types", type, [:id, :name]))
      assert(has_table_row?(index_live, "#types", other, [:id, :name]))

      filter(index_live, 3, "2020-02-15 14:59")

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#types", type, [:id, :name]))
      assert(has_table_row?(index_live, "#types", other, [:id, :name]))

      filter(index_live, 3, "2020-02-15 09:59")

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 3, 2, "datetime-local")
      assert_filter_param_handling(conn, "product_types", 3, :inserted_at, :<=)
    end

    test "filters product types by whether a product type is assignable",
         %{conn: conn, type: assignable} do
      unassignable = product_type_fixture(%{assignable: false})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 2)

      filter(index_live, 4, true)

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#types", assignable, [:id, :name]))
      refute(has_table_row?(index_live, "#types", unassignable, [:id, :name]))

      filter(index_live, 4, false)

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#types", assignable, [:id, :name]))
      assert(has_table_row?(index_live, "#types", unassignable, [:id, :name]))
      assert_filter_param_handling(conn, "product_types", 4, :assignable, :==)
    end

    test "filters product types by whether a product type has any products",
         %{conn: conn, type: with_products} do
      product_fixture(%{product_type: with_products})

      productless = product_type_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 2)

      filter(index_live, 5, true)

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#types", with_products, [:id, :name]))
      refute(has_table_row?(index_live, "#types", productless, [:id, :name]))

      filter(index_live, 5, false)

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#types", with_products, [:id, :name]))
      assert(has_table_row?(index_live, "#types", productless, [:id, :name]))

      assert_filter_param_handling(
        conn,
        "product_types",
        5,
        :has_products,
        :!=
      )
    end

    test "sorts product types by the ID", %{conn: conn, type: type} do
      ids = [type.id | Enum.map(0..1, fn _ -> product_type_fixture().id end)]
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_sorting(index_live, ids, "ID")
      assert_sort_param_handling(conn, "product_types", :id)
    end

    test "sorts product types by name", %{conn: conn, type: type} do
      other = product_type_fixture(%{name: "Other name"})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_sorting(index_live, [type.name, other.name], "Name")
      assert_sort_param_handling(conn, "product_types", :name)
    end

    test "sorts product types by the description", %{conn: conn, type: type} do
      other = product_type_fixture(%{description: "Other description"})
      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_sorting(index_live, [type.description, other.description], "Desc")
      assert_sort_param_handling(conn, "product_types", :description)
    end

    test "sorts product types by the creation date",
         %{conn: conn, type: type} do
      values =
        Enum.map([{type, 15}, {product_type_fixture(), 10}], fn {tp, hour} ->
          value = "2020-02-15 #{hour}:00:00"
          {:ok, _updated} = DataCase.update_inserted_at(tp, value <> "Z")

          value
        end)

      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_sorting(index_live, values, "Creation date and time")
      assert_sort_param_handling(conn, "product_types", :inserted_at)
    end

    test "sorts product types by whether they are assignable", %{conn: conn} do
      product_type_fixture(%{assignable: false})

      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_sorting(index_live, ["Yes", ""], "Assignable")
      assert_sort_param_handling(conn, "product_types", :assignable)
    end

    test "sorts product types by multiple columns",
         %{conn: conn, type: type} do
      Enum.each(["A", "A", "Z", "Z"], fn letter ->
        product_type_fixture(%{description: letter, assignable: false})
      end)

      product_type_fixture(%{description: "B"})

      by_desc_id = order_params([:description, :id], [:asc, :desc])
      {:ok, index_live, _html} = live(conn, ~p"/product_types?#{by_desc_id}")
      ids_desc = column_values(index_live, 1)

      # "Description" column values.
      index_live
      |> column_values(3)
      |> Kernel.==(["A", "A", "B", type.description, "Z", "Z"])
      |> assert()

      assert_table_row_count(index_live, 6)
      assert(sorted?(Enum.take(ids_desc, 2), :desc))
      assert(sorted?(Enum.take(ids_desc, -2), :desc))
      refute(sorted?(ids_desc, :desc))

      by_assignable_id = order_params([:assignable, :id], [:desc, :asc])
      {:ok, live, _html} = live(conn, ~p"/product_types?#{by_assignable_id}")
      ids_asc = column_values(live, 1)

      # "Assignable" column values.
      assert(column_values(live, 5) == ["Yes", "Yes", "", "", "", ""])
      assert(sorted?(Enum.take(ids_asc, 2), :asc))
      assert(sorted?(Enum.take(ids_asc, -4), :asc))
      refute(sorted?(ids_asc, :asc))
    end

    test "switches between pages of product type results", %{conn: conn} do
      Enum.each(0..24, fn _ -> product_type_fixture() end)

      {:ok, index_live, _html} = live(conn, ~p"/product_types")

      assert_table_row_count(index_live, 25)
      assert(has_n_children?(index_live, "nav.pagination > ul", 2))

      index_live
      |> has_element?("#pagination-counter", "26 results (25 on the current")
      |> assert()

      {:ok, live, _html} = live(conn, ~p"/product_types")

      click(live, "nav.pagination > ul > :nth-child(2) > a")

      assert_table_row_count(live, 1)

      live
      |> has_element?("#pagination-counter", "26 results (1 on the current")
      |> assert()

      assert_page_param_handling(conn, "product_types")
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_log_in_page(conn, ~p"/product_types/#{type}")
      assert_redirect_to_log_in_page(conn, ~p"/product_types/#{type}/show")

      assert_redirect_to_log_in_page(
        conn,
        ~p"/product_types/#{type}/show/edit"
      )
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_product_type]

    test "gets redirected away", %{conn: conn, type: type} do
      assert_redirect_to_main_page(conn, ~p"/product_types/#{type}")
      assert_redirect_to_main_page(conn, ~p"/product_types/#{type}/show")
      assert_redirect_to_main_page(conn, ~p"/product_types/#{type}/show/edit")
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
      other_type = product_type_fixture(%{name: "TAKEN_"})
      {:ok, show_live, _html} = live(conn, ~p"/product_types/#{type}")

      assert(list_item_value(show_live, "Assignable to products") == "Yes")

      show_live
      |> click("div.flex-none > a", "Edit")
      |> assert_match("Edit product type ID #{type.id}")

      assert_patch(show_live, ~p"/product_types/#{type}/show/edit")
      assert_form_errors(show_live, other_type.name)
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
      assert_table_row_count(index_live, 0)
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

  @spec assert_form_errors(%View{}, String.t()) :: boolean()
  defp assert_form_errors(%View{} = lv, taken_name) do
    assert(form_errors(lv, "#product-type-form") == [])
    assert_form_name_taken_errors(lv, taken_name)

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

  @spec assert_form_name_taken_errors(%View{}, String.t()) :: boolean()
  defp assert_form_name_taken_errors(%View{} = lv, taken_name) do
    change_form(lv, %{name: "  " <> taken_name <> " "})

    assert(has_form_error?(lv, "#product-type-form", :name, "eady been taken"))

    change_form(lv, %{name: "   " <> String.upcase(taken_name) <> "  "})

    assert(has_form_error?(lv, "#product-type-form", :name, "eady been taken"))

    change_form(lv, %{name: " " <> String.downcase(taken_name) <> "   "})

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
  @spec change_form(%View{}, %{atom() => any()}) ::
          String.t() | redirect_error()
  defp change_form(%View{} = live_view, type_data) do
    change(live_view, "#product-type-form", %{product_type: type_data})
  end
end
