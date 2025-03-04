defmodule CloudDbUiWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use CloudDbUiWeb, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates/1 call below
  # and add pages to the error directory:
  #
  #   * lib/cloud_db_ui_web/controllers/error_html/404.html.heex
  #   * lib/cloud_db_ui_web/controllers/error_html/500.html.heex
  #
  embed_templates "error_html/*"

  def render("not_found.html", assigns) do
    apply(__MODULE__, :"404", [assigns])
  end

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  # def render(template, _assigns) do
  #   Phoenix.Controller.status_message_from_template(template)
  # end

  @spec back_navigate_path(%{atom() => any()}) :: String.t()
  defp back_navigate_path(%{conn: %Plug.Conn{request_path: req_path}}) do
    ["users", "product_types", "products", "orders", "sub-orders"]
    |> Enum.find(&String.starts_with?(req_path, "/" <> &1))
    |> case do
      nil -> ~p"/"
      prefix -> ~p"/#{prefix}"
    end
  end

  # No `:conn` in `assigns`.
  defp back_navigate_path(_assigns), do: ~p"/"
end
