defmodule CloudDbUiWeb.PageControllerTest do
  use CloudDbUiWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn
    |> get(~p"/platform")
    |> html_response(200)
    |> assert_match("Peace of mind from prototype to production")
  end
end
