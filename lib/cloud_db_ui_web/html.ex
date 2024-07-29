defmodule CloudDbUiWeb.HTML do
  alias CloudDbUiWeb.Utilities

  @doc """
  Label text with a character counter.
  Displays the counter when an `input` is not blank.
  """
  @spec label_text(String.t(), any(), non_neg_integer() | nil) :: String.t()
  def label_text(label, input, limit \\ nil) do
    input
    |> to_string()
    |> String.trim()
    |> case do
      "" -> label
      trimmed -> append_character_counter(label, trimmed, limit)
    end
  end

  @doc """
  Create a hyperlink to a passed `url`.
  """
  @spec link(String.t(), String.t(), String.t() | nil) :: {:safe, list()}
  def link(text, url, class \\ nil) do
    Phoenix.HTML.Link.link(text, [to: url, class: class])
  end

  @doc """
  An `img` tag.
  """
  @spec img(String.t(), String.t(), non_neg_integer()) ::
          String.t() | nil | {:safe, list()}
  def img(img_serv_path, alt, width), do: img(img_serv_path, alt, width, true)

  # Image path not set, no need to load.
  @spec img(nil, String.t(), non_neg_integer(), boolean()) :: nil
  def img(nil, _alt, _width, _load_image?), do: nil

  # Image path set, but loading is not allowed.
  @spec img(String.t(), String.t(), non_neg_integer(), false) :: String.t()
  def img(_path_at_img_server, alt, _width, false = _load_image?), do: alt

  # Image path set, and loading is allowed. If the loading fails,
  # the image will be replaced with the `alt` string.
  @spec img(String.t(), String.t(), non_neg_integer(), true) :: {:safe, list()}
  def img(path_at_img_server, alt, width, true = _load_image?) do
    img_tag(path_at_img_server, alt, width)
  end

  @spec img_tag(String.t(), String.t(), non_neg_integer()) :: {:safe, list()}
  defp img_tag(path_at_img_server, alt, width) do
    path_at_img_server
    |> img_src()
    |> Phoenix.HTML.Tag.img_tag([alt: alt, width: width])
  end

  # This `nil` will make the image get replaced by the value of `alt`.
  @spec img_src(nil) :: nil
  defp img_src(nil), do: nil

  # Download an image from the image server and prepare the value
  # of the `src` attribute for an `img` tag.
  @spec img_src(String.t()) :: binary() | nil
  defp img_src(path_at_img_server) when is_binary(path_at_img_server) do
    path_at_img_server
    |> CloudDbUiWeb.ImageServer.download()
    |> img_src()
  end

  @spec img_src(
          {:error, String.t()} | {pos_integer(), String.t(), binary()}
        ) :: binary() | nil
  defp img_src({200, content_type, bytes}) do
    "data:#{content_type};base64, " <> Base.encode64(bytes)
  end

  # Failed to load.
  # This `nil` will make the image get replaced by the value of `alt`.
  defp img_src(_error_or_not_code_200), do: nil

  # If a label ends with `")"`, replace this `")"` with `", "`,
  # , otherwise add `" ("` before appending the character counter.
  # Expects trimmed `input`.
  @spec append_character_counter(
          String.t(),
          String.t(),
          non_neg_integer() | nil
        ) :: String.t()
  defp append_character_counter(label, input, limit) do
    case String.ends_with?(label, ")") do
      true -> String.replace(label, ~r/\)$/, ", ")
      false -> label <> " ("
    end
    |> Kernel.<>(character_counter(input, limit))
  end

  @spec character_counter(String.t(), non_neg_integer() | nil) :: String.t()
  defp character_counter(input, nil) do
    input_length = String.length(input)

    case Utilities.needs_plural_form?(input_length) do
      true -> "#{input_length} characters"
      false -> "#{input_length} character"
    end
  end

  defp character_counter(input, limit) when limit >= 1 do
    Kernel.<>(
      "#{String.length(input)}/#{limit} character",
      "#{if Utilities.needs_plural_form?(limit), do: "s"})"
    )
  end
end
