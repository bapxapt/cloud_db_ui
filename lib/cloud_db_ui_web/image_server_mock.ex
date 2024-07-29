defmodule CloudDbUiWeb.ImageServerMock do
  use CloudDbUiWeb, :controller

  import CloudDbUiWeb.Utilities, [only: [find_header_value: 2]]

  @type params() :: CloudDbUi.Type.params()

  @spec up?(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def up?(conn, _params), do: send_resp(conn, 200, "up")

  @spec upload(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def upload(conn, %{"file" => upload} = _params) do
    if token_type(conn.req_headers) == :token_rw do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        201,
        Jason.encode!(%{ok: true, path: "/files/" <> upload.filename})
      )
    else
      send_resp_unauthorized(conn)
    end
  end

  @spec download(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def download(conn, _params) do
    if token_type(conn.req_headers) in [:token_ro, :token_rw] do
      conn
      |> put_resp_content_type("image/png")
      |> send_resp(200, File.read!("./deps/phoenix/priv/static/phoenix.png"))
    else
      send_resp_unauthorized(conn)
    end
  end

  @spec send_resp_unauthorized(%Plug.Conn{}) :: %Plug.Conn{}
  defp send_resp_unauthorized(%Plug.Conn{} = conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{ok: false, error: "unauthorized"}))
  end

  @spec get_token_from_headers([{String.t(), String.t()}]) :: String.t() | nil
  defp get_token_from_headers(request_headers) do
    request_headers
    |> find_header_value("authorization")
    |> case do
      "Bearer " <> bearer_token -> bearer_token
      "token=" <> token -> token
      _any -> nil
    end
  end

  @spec token_type([{String.t(), String.t()}]) :: :token_ro | :token_rw | nil
  defp token_type(request_headers) when is_list(request_headers) do
    request_headers
    |> get_token_from_headers()
    |> token_type()
  end

  @spec token_type(String.t() | nil) :: :token_ro | :token_rw | nil
  defp token_type("mock_token_ro_6e725b"), do: :token_ro

  defp token_type("mock_token_rw_b4a3c0"), do: :token_rw

  defp token_type(_wrong_token), do: nil
end
