defmodule CloudDbUiWeb.JavaScript do
  alias Phoenix.LiveView.Socket

  @doc """
  Send a `"js_set_attribute"` event to be processed by
  `window.addEventListener("phx:js_set_attribute", ({detail})` in `app.js`.
  """
  @spec js_set_attribute(%Socket{}, String.t(), %{String.t() => any()}) ::
          %Socket{}
  def js_set_attribute(socket, selector, attributes) do
    Phoenix.LiveView.push_event(
      socket,
      "js_set_attribute",
      %{selector: selector, attributes: attributes}
    )
  end

  @doc """
  Send a `"js_hide"` event to be processed by
  `window.addEventListener("phx:js_hide", ({detail})` in `app.js`.
  """
  @spec js_hide(%Socket{}, String.t(), non_neg_integer()) :: %Socket{}
  def js_hide(socket, selector, time \\ 200) do
    Phoenix.LiveView.push_event(
      socket,
      "js_hide",
      %{selector: selector, time: time}
    )
  end

  @doc """
  Send a `"js_set_text"` event to be processed by
  `window.addEventListener("phx:js_set_text", ({detail})` in `app.js`.
  """
  @spec js_set_text(%Socket{}, String.t(), String.t()) :: %Socket{}
  def js_set_text(socket, selector, text_new) do
    Phoenix.LiveView.push_event(
      socket,
      "js_set_text",
      %{selector: selector, text: text_new}
    )
  end

  @doc """
  Send a `"delete"` event and hide an element.
  `values` is a map of parameters for `handle_event()`.

  Keep in mind that for consistency all values in that map
  should be strings.
  """
  @spec js_delete(String.t(), boolean(), struct() | %{atom() => any()}) ::
          %Phoenix.LiveView.JS{}
  def js_delete(html_id, deletable?, %{__struct__: _} = object) do
    js_delete(html_id, deletable?, %{id: "#{object.id}"})
  end

  # Deletable; send the "delete" event and hide the stream entry.
  def js_delete(html_id, true = _deletable?, values) do
    values
    |> js_push_delete()
    |> CloudDbUiWeb.CoreComponents.hide("##{html_id}")
  end

  # Not deletable; only send the "delete" event.
  def js_delete(_id, false = _deletable?, values), do: js_push_delete(values)

  # Send the "delete" event.
  @spec js_push_delete(%{atom() => any()}) :: %Phoenix.LiveView.JS{}
  defp js_push_delete(values) do
    Phoenix.LiveView.JS.push("delete", [value: values])
  end
end
