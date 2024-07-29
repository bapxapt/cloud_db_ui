defmodule CloudDbUiWeb.ImageServer do
  @moduledoc """
  A module for interaction with `mayth/simple-upload-server:v1`.

  Depends on the following environment variables:

  - CLOUD_DB_UI_IMAGE_SERVER_TOKEN - an image server token;
  - CLOUD_DB_UI_IMAGE_SERVER_HOST - a host name.

  CLOUD_DB_UI_IMAGE_SERVER_HOST is optional (defaults to `"localhost"`).
  """

  @doc """
  Check whether the image server is running.
  """
  @spec up?() :: boolean()
  def up?(), do: up?(100)

  @spec up?(non_neg_integer()) :: boolean()
  def up?(timeout) when is_integer(timeout) do
    host_root_url()
    |> HTTPoison.get([], [timeout: timeout])
    |> up?()
  end

  @spec up?({:ok, %HTTPoison.Response{}}) :: boolean()
  def up?({:ok, %HTTPoison.Response{} = _response}), do: true

  @spec up?({:error, %HTTPoison.Error{}}) :: boolean()
  def up?({:error, %HTTPoison.Error{} = _error}), do: false

  @doc """
  Download a file from the image server.
  """
  @spec download(String.t()) ::
          {pos_integer(), String.t(), any()} | {:error, String.t()}
  def download(path, timeout \\ 100) do
    host_root_url()
    |> Kernel.<>(path)
    |> HTTPoison.get([], [params: params(), timeout: timeout])
    |> handle_response(false)
  end

  @doc """
  Upload a file taken from `path` to the image server.
  If `name` is specified, the file gets renamed at the image server
  after the uploading.
  """
  @spec upload(String.t()) ::
          {pos_integer(), String.t(), any()} | {:error, String.t()}
  def upload(path), do: upload(path, nil)

  @spec upload(String.t(), nil) ::
          {pos_integer(), String.t(), any()} | {:error, String.t()}
  def upload(path, nil = _name) do
    host_root_url()
    |> Kernel.<>("/upload")
    |> HTTPoison.post(
      {:multipart, [{:file, path}]},
      headers(),
      [params: params()]
    )
    |> handle_response(true)
  end

  @spec upload(String.t(), String.t()) ::
          {pos_integer(), String.t(), any()} | {:error, String.t()}
  def upload(path, name) do
    host_root_url()
    |> Kernel.<>("/files/#{name}")
    |> HTTPoison.put(
      {:multipart, [{:file, path}]},
      headers(),
      [params: params()]
    )
    |> handle_response(true)
  end

  @doc """
  The rool URL of the image server. An example: `http://localhost:25478`.
  """
  @spec host_root_url() :: String.t()
  def host_root_url() do
    "http://"
    |> Kernel.<>(System.get_env("CLOUD_DB_UI_IMAGE_SERVER_HOST", "localhost"))
    |> Kernel.<>(":25478")
  end

  @spec handle_response({:ok, %HTTPoison.Response{}}, boolean()) ::
          {pos_integer(), String.t(), any()}
  defp handle_response({:ok, %{body: body} = response}, true = _decode?) do
    {
      response.status_code,
      content_type(response.headers),
      maybe_decode_body(body)
    }
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

  @spec content_type([{String.t(), String.t()}]) :: String.t()
  defp content_type(response_headers) do
    response_headers
    |> Enum.find(&(elem(&1, 0) == "Content-Type"))
    |> elem(1)
  end

  @spec params() :: [{String.t(), String.t()}]
  defp params() do
    [{"token", System.get_env("CLOUD_DB_UI_IMAGE_SERVER_TOKEN")}]
  end

  @spec headers() :: [{String.t(), String.t()}]
  defp headers() do
    [{"Content-Type", "multipart/form-data; boundary=-----s2FiIUfjefmk09"}]
  end
end
