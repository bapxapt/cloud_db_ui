defmodule CloudDbUiWeb.JavaScript do
  alias Phoenix.LiveView.{Socket, JS}

  import Phoenix.LiveView

  @doc """
  Set the editable value and the `value=""` attribute of an input field
  while setting the cursor after the last non-space character.
  """
  @spec set_input_field_value(%Socket{}, String.t(), any()) :: %Socket{}
  def set_input_field_value(%Socket{} = socket, selector, value) do
    last_index =
      case Regex.run(~r/\S(?=\s*$)/, "#{value}", [return: :index]) do
        [{index, 1}] -> index + 1
        nil -> String.length("#{value}")
      end

    socket
    |> js_set_value(selector, value)
    |> js_set_attribute(selector, %{"value" => value})
    |> js_set_selection_range(selector, last_index, last_index)
  end

  @doc """
  Send a `"js_set_attribute"` event to be processed by
  `window.addEventListener("phx:js_set_attribute", ({detail})` in `app.js`.
  """
  @spec js_set_attribute(%Socket{}, String.t(), %{String.t() => any()}) ::
          %Socket{}
  def js_set_attribute(%Socket{} = socket, selector, attributes) do
    push_event(
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
  def js_hide(%Socket{} = socket, selector, time \\ 200) do
    push_event(socket, "js_hide", %{selector: selector, time: time})
  end

  @doc """
  Send a `"js_set_text"` event to be processed by
  `window.addEventListener("phx:js_set_text", ({detail})` in `app.js`.
  """
  @spec js_set_text(%Socket{}, String.t(), String.t()) :: %Socket{}
  def js_set_text(%Socket{} = socket, selector, text_new) do
    push_event(socket, "js_set_text", %{selector: selector, text: text_new})
  end

  @doc """
  Send a `"js_set_value"` event to be processed by
  `window.addEventListener("phx:js_set_value", ({detail})` in `app.js`.
  """
  @spec js_set_value(%Socket{}, String.t(), String.t()) :: %Socket{}
  def js_set_value(%Socket{} = socket, selector, value_new) do
    push_event(socket, "js_set_value", %{selector: selector, value: value_new})
  end

  @doc """
  Send a `"js_set_selection_range"` event to be processed by
  `window.addEventListener("phx:js_set_selection_range", ({detail})`
  in `app.js`.
  """
  @spec js_set_selection_range(%Socket{}, String.t(), integer(), integer()) ::
          %Socket{}
  def js_set_selection_range(%Socket{} = socket, selector, from, to) do
    push_event(
      socket,
      "js_set_selection_range",
      %{selector: selector, start: from, end: to}
    )
  end

  @doc """
  Send a `"delete"` event and hide an element.
  `values` is a map of parameters for `handle_event()`.

  For consistency, all values in that map should be strings.
  """
  @spec js_delete(String.t(), boolean(), struct() | %{atom() => String.t()}) ::
          %JS{}
  def js_delete(html_id, deletable?, %{__struct__: _, id: id} = _object) do
    js_delete(html_id, deletable?, %{id: "#{id}"})
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
  @spec js_push_delete(%{atom() => String.t()}) :: %JS{}
  defp js_push_delete(values), do: JS.push("delete", [value: values])
end
