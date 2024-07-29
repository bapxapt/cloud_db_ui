defmodule CloudDbUiWeb.PageControllerTest do
  use CloudDbUiWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/platform")

    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end
