defmodule CloudDbUiWeb.SubOrderLiveTest do
  use CloudDbUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import CloudDbUi.OrdersFixtures

  @create_attrs %{quantity: 42, unit_price: 120.5}
  @update_attrs %{quantity: 43, unit_price: 456.7}
  @invalid_attrs %{quantity: nil, unit_price: nil}

  defp create_suborder(_) do
    suborder = suborder_fixture()
    %{suborder: suborder}
  end

  describe "Index" do
    setup [:create_suborder]

    test "lists all suborders", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/sub-orders")

      assert html =~ "Listing order positions"
    end

    test "saves new suborder", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      assert index_live |> element("a", "New sub-order") |> render_click() =~
               "New sub-order"

      assert_patch(index_live, ~p"/sub-orders/new")

      assert index_live
             |> form("#suborder-form", suborder: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#suborder-form", suborder: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/sub-orders")

      html = render(index_live)
      assert html =~ "SubOrder created successfully"
    end

    test "updates suborder in listing", %{conn: conn, suborder: suborder} do
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      assert index_live |> element("#suborders-#{suborder.id} a", "Edit") |> render_click() =~
               "Edit sub-order"

      assert_patch(index_live, ~p"/sub-orders/#{suborder}/edit")

      assert index_live
             |> form("#suborder-form", suborder: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#suborder-form", suborder: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/sub-orders")

      html = render(index_live)
      assert html =~ "SubOrder updated successfully"
    end

    test "deletes suborder in listing", %{conn: conn, suborder: suborder} do
      {:ok, index_live, _html} = live(conn, ~p"/sub-orders")

      assert index_live |> element("#suborders-#{suborder.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#suborders-#{suborder.id}")
    end
  end

  describe "Show" do
    setup [:create_suborder]

    test "displays suborder", %{conn: conn, suborder: suborder} do
      {:ok, _show_live, html} = live(conn, ~p"/sub-orders/#{suborder}")

      assert html =~ "Show sub-order"
    end

    test "updates suborder within modal", %{conn: conn, suborder: suborder} do
      {:ok, show_live, _html} = live(conn, ~p"/sub-orders/#{suborder}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit sub-order"

      assert_patch(show_live, ~p"/sub-orders/#{suborder}/show/edit")

      assert show_live
             |> form("#suborder-form", suborder: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#suborder-form", suborder: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/sub-orders/#{suborder}")

      html = render(show_live)
      assert html =~ "SubOrder updated successfully"
    end
  end
end
