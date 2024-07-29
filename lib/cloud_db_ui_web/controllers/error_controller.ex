defmodule CloudDbUiWeb.ErrorController do
  use CloudDbUiWeb, :controller

  def not_found(conn, _params), do: render(conn)
end
