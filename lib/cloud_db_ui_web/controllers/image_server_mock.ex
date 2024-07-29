defmodule CloudDbUiWeb.ImageServerMock do
  use CloudDbUiWeb, :controller

  @type params() :: CloudDbUi.Type.params()

  @spec up?(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def up?(conn, _params), do: send_resp(conn, 200, "up")

  @spec upload(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def upload(conn, params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      201,
      Jason.encode!(%{ok: true, path: "/files/" <> params["file"].filename})
    )
  end

  @spec download(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def download(conn, _params) do
    conn
    |> put_resp_content_type("image/png")
    |> send_resp(200, File.read!("./deps/phoenix/priv/static/phoenix.png"))
  end
end
