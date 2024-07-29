defmodule CloudDbUiWeb.ErrorJSONTest do
  use CloudDbUiWeb.ConnCase, async: true

  test "renders 404" do
    "404.json"
    |> CloudDbUiWeb.ErrorJSON.render(%{})
    |> Kernel.==(%{errors: %{detail: "Not Found"}})
    |> assert()
  end

  test "renders 500" do
    "500.json"
    |> CloudDbUiWeb.ErrorJSON.render(%{})
    |> Kernel.==(%{errors: %{detail: "Internal Server Error"}})
    |> assert()
  end
end
