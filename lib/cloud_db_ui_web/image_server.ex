defmodule CloudDbUiWeb.ImageServer do
  @moduledoc """
  A module for interaction with `mayth/simple-upload-server:v1`.

  Depends on the following environment variables:

  - IMAGE_SERVER_RO_TOKEN - a read-only image server token;
  - IMAGE_SERVER_RW_TOKEN - a read-write image server token;
  - IMAGE_SERVER_HOST - a host name (with a port).

  IMAGE_SERVER_HOST is optional (defaults to `"localhost:25478"`).
  """

  import CloudDbUiWeb.Utilities, [only: [find_header_value: 2]]

  @doc """
  Check whether the image server is running.
  """
  @spec up?() :: boolean()
  def up?() do
    task =
      Task.async(fn ->
        origin_url()
        |> HTTPoison.get()
      end)

    case Task.yield(task, timeout()) || Task.shutdown(task) do
      {:ok, {:ok, %HTTPoison.Response{}}} -> true
      _any -> false
    end
  end

  @doc """
  Download a file from the image server.
  """
  @spec download(String.t()) ::
          {pos_integer(), String.t(), any()} | {:error, String.t()}
  def download(path, timeout \\ 100) do
    origin_url()
    |> Kernel.<>(path)
    |> HTTPoison.get(
      [authorization_header(:token_ro)],
      [timeout: timeout]
    )
    |> handle_response(false)
  end

  @doc """
  Upload a file taken from a `source_path` to the image server.
  If a `name_at_server` is specified, the file gets renamed
  at the image server after the uploading.
  """
  @spec upload(String.t(), String.t() | nil) ::
          {pos_integer(), String.t(), any()} | {:error, String.t()}
  def upload(source_path, name_at_server \\ nil) do
    name_at_server
    |> upload_url()
    |> HTTPoison.post(
      {:multipart, [{:file, source_path}]},
      [content_type_header(), authorization_header(:token_rw)]
    )
    |> handle_response(true)
  end

  @spec handle_response({:ok, %HTTPoison.Response{}}, boolean()) ::
          {pos_integer(), String.t(), any()}
  defp handle_response({:ok, %{body: body} = resp}, true = _decode?) do
    {resp.status_code, content_type(resp.headers), maybe_decode_body(body)}
  end

  defp handle_response({:ok, %{body: body} = response}, false = _decode?) do
    {response.status_code, content_type(response.headers), body}
  end

  @spec handle_response({:error, %HTTPoison.Error{}}, boolean()) ::
          {:error, String.t()}
  defp handle_response({:error, %{reason: reason}}, _decode?) do
    {:error, inspect(reason)}
  end

  @spec maybe_decode_body(String.t()) :: any()
  defp maybe_decode_body(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _decode_error} -> body
    end
  end

  @spec upload_url(String.t() | nil) :: String.t()
  defp upload_url(name_at_server) when name_at_server in [nil, ""] do
    origin_url() <> "/upload"
  end

  # A non-blank `name_at_server`, the file will be renamed after uploading.
  defp upload_url(name_at_server) do
    origin_url() <> "/files/" <> name_at_server
  end

  # The origin URL of the image server, like `http://localhost:25478`.
  @spec origin_url() :: String.t()
  defp origin_url(), do: "http://" <> host()

  @spec host() :: String.t()
  defp host(), do: Application.get_env(:cloud_db_ui, __MODULE__)[:hostname]

  @spec timeout() :: timeout()
  def timeout() do
    Application.get_env(:cloud_db_ui, __MODULE__)[:timeout] || 100
  end

  @spec content_type([{String.t(), String.t()}]) :: String.t() | nil
  defp content_type(response_headers) do
    response_headers
    |> find_header_value("content-type")
  end

  @spec content_type_header() :: {String.t(), String.t()}
  defp content_type_header() do
    {
      "Content-Type",
      "multipart/form-data; boundary=-------------------V1elLbyRkrBuUkHlbUN8ab"
    }
  end

  @spec authorization_header(atom()) :: {String.t(), String.t()}
  defp authorization_header(key) when key in [:token_ro, :token_rw] do
    {"Authorization", "Bearer #{token(key)}"}
  end

  @spec token(:token_ro | :token_rw) :: String.t() | nil
  defp token(key), do: Application.get_env(:cloud_db_ui, __MODULE__)[key]
end
