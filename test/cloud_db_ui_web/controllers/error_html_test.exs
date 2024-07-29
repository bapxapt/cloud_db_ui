defmodule CloudDbUiWeb.ErrorHTMLTest do
  use CloudDbUiWeb.ConnCase, async: true

  # Bring `&render_to_string/4` for testing custom views.
  import Phoenix.Template

  test "renders 404.html" do
    CloudDbUiWeb.ErrorHTML
    |> render_to_string("404", "html", [])
    |> assert_match("404 not found")
  end

  test "renders 500.html" do
    CloudDbUiWeb.ErrorHTML
    |> render_to_string("500", "html", [])
    |> assert_match("500 internal server error")
  end
end
