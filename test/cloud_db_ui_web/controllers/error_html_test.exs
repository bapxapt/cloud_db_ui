defmodule CloudDbUiWeb.ErrorHTMLTest do
  use CloudDbUiWeb.ConnCase, async: true

  # Bring `&render_to_string/4` for testing custom views.
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(CloudDbUiWeb.ErrorHTML, "404", "html", []) =~ "404 not found"
  end

  test "renders 500.html" do
    assert render_to_string(CloudDbUiWeb.ErrorHTML, "500", "html", []) =~ "500 internal server error"
  end
end
