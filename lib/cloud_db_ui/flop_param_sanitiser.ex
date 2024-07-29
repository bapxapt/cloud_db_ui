defmodule CloudDbUi.FlopParamSanitiser do
  import CloudDbUiWeb.Utilities

  @type params() :: CloudDbUi.Type.params()

  @doc """
  Sanitise values of the following keys in `params`: `"filters"`,
  `"order"`, `"order_by"`, `"order_directions"`, `"page"`.
  """
  @spec sanitise_params(params(), keyword(keyword()), [atom()]) :: params()
  def sanitise_params(%{} = params, form_field_opts, sortable_fields) do
    params
    |> sanitise_filter_params(form_field_opts)
    |> sanitise_order_params(sortable_fields)
    |> sanitise_page_params()
  end

  @doc """
  Delete the `"order"` key from `params` if its value is invalid.
  Remove any invalid field names from the list under `"order_by"`
  and corresponding elements in the list under `"order_directions"`.
  Replace invalid elements of the `"order_directions"` list with `"asc"`.

  `These values have the following shape in `:params` of a `%Meta{}`:
  `%{"order" => "fld", order_by => ["fld"], "order_directions" => ["asc"]}`.
  """
  @spec sanitise_order_params(params(), [atom()]) :: params()
  def sanitise_order_params(%{} = params, sortable_fields) do
    indices_excluded = invalid_indices_in_order_by(params, sortable_fields)

    case sortable_field?(params["order"], sortable_fields) do
      true -> params
      false -> Map.delete(params, "order")
    end
    |> maybe_delete_list_param_value_elements("order_by", indices_excluded)
    |> maybe_delete_list_param_value_elements(
      "order_directions",
      indices_excluded
    )
  end

  @doc """
  Delete the `"page"` key from `params` if its value
  is not a representation of an integer.
  """
  @spec sanitise_page_params(params()) :: params()
  def sanitise_page_params(%{} = params) do
    if is_binary(params["page"]) and valid_number_format?(params["page"], 0) do
      params
    else
      Map.delete(params, "page")
    end
  end

  # Construct the list of filter params under the `"filters"` key.
  # Sanitise incorrect indices and field names, but not `"value"`s.
  #
  # `"filters"` has the following shape in `:params` of a `%Meta{}`:
  # `%{"filters" => [%{"field" => "a", "op" => "==", "value" => ""}]}`.
  @spec sanitise_filter_params(params(), keyword(keyword())) :: params()
  defp sanitise_filter_params(%{} = params, form_field_opts) do
    Map.replace_lazy(params, "filters", fn filter_params ->
      if is_map(filter_params) do
        form_field_opts
        |> Enum.with_index()
        |> Map.new(fn {{field, opts}, index} ->
          {
            "#{index}",
            sanitise_filter_params(filter_params, field, opts, index)
          }
        end)
      else
        form_field_opts
        |> Enum.with_index()
        |> Enum.map(fn {{field, opts}, index} ->
          sanitise_filter_params(filter_params, field, opts, index)
        end)
      end
    end)
  end

  @spec sanitise_filter_params(
          params() | [params()],
          atom(),
          keyword(),
          non_neg_integer()
        ) :: params()
  defp sanitise_filter_params(filter_params, field_name, field_opts, index) do
    filter =
      cond do
        is_map(filter_params) -> filter_params["#{index}"]
        is_list(filter_params) -> Enum.at(filter_params, index)
        true -> nil
      end

    case valid_filter_params_field_and_op?(filter, field_name, field_opts) do
      true -> Map.put_new(filter, "value", "")
      false -> construct_meta_params_for_field!(field_name, field_opts)
    end
  end

  # An index is lnvalid if any condition is true:
  #
  #   - a non-sortable field at this index in `sortable`;
  #   - a direction exists at this index in `params["order_directions"]`,
  #     but is invalid.
  @spec invalid_indices_in_order_by(params(), [atom()]) :: [non_neg_integer()]
  defp invalid_indices_in_order_by(%{"order_by" => by} = params, sortable_flds)
       when is_list(by) do
    directions =
      params
      |> Map.get("order_directions", [])
      |> case do
        list when is_list(list) -> list
        _any -> []
      end

    by
    |> Stream.with_index()
    |> Stream.filter(fn {field, index} ->
      direction = Enum.at(directions, index)

      cond do
        !sortable_field?(field, sortable_flds) -> true
        direction != nil and !valid_order_direction?(direction) -> true
        true -> false
      end
    end)
    |> Enum.map(&elem(&1, 1))
  end

  # No `"order_by"`, or its value is not a list.
  defp invalid_indices_in_order_by(_params, _sortable_fields), do: []

  # If the value under the `key` is a list, delete its elements
  # at `indices`. If it is not a list, replace it with `""` in order
  # for the atom-converted `key` in a `%Flop{}` to be correctly
  # replaced with `nil`.
  @spec maybe_delete_list_param_value_elements(
          params(),
          String.t(),
          [non_neg_integer()]
        ) :: params()
  defp maybe_delete_list_param_value_elements(%{} = params, key, indices) do
    Map.replace_lazy(params, key, fn value ->
      case is_list(value) do
        true -> delete_at(value, indices)
        false -> ""
      end
    end)
  end

  # `:params` in a `%Meta{}` have the following shape:
  # `%{"filters" => [%{"field" => "a", "op" => "==", "value" => ""}]}`.
  # This constructs a single element (which is a map) of the list
  # under the `"filters"` key.
  @spec construct_meta_params_for_field!(atom(), keyword()) :: params()
  defp construct_meta_params_for_field!(field, field_opts) do
    %{
      "field" => "#{field}",
      "op" => "#{Keyword.fetch!(field_opts, :op)}",
      "value" => ""
    }
  end

  # Check whether the passed `filter` params have a valid value
  # of `"field"` and `"op"`. The vlaue of `"value"` does not get checked.
  @spec valid_filter_params_field_and_op?(any(), atom(), keyword()) ::
          boolean()
  defp valid_filter_params_field_and_op?(filter, field, field_opts) do
    cond do
      !is_map(filter) -> false
      !filterable_field?(filter["field"], field) -> false
      !allowed_op?(filter["op"] || "==", field_opts) -> false
      true -> true
    end
  end

  @spec valid_order_direction?(any()) :: boolean()
  defp valid_order_direction?(dir) when not is_binary(dir), do: false

  defp valid_order_direction?(direction) do
    [
      :asc,
      :asc_nulls_first,
      :asc_nulls_last,
      :desc,
      :desc_nulls_first,
      :desc_nulls_last
    ]
    |> Enum.member?(to_existing_atom(direction))
  end

  # A list of `:sortable` fields in a `@derive`d `Flop.Schema`
  # is supposed to not contain a `nil` element.
  @spec sortable_field?(any(), [atom()]) :: boolean()
  defp sortable_field?(value, _sortable) when not is_binary(value), do: false

  defp sortable_field?(val, sortable), do: to_existing_atom(val) in sortable

  # `&to_existing_atom/1` might return `nil`, but a list of `:filterable`
  # fields in a `@derive`d `Flop.Schema` cannot ever contain `nil`.
  @spec filterable_field?(any(), atom()) :: boolean()
  defp filterable_field?(value, _field) when not is_binary(value), do: false

  defp filterable_field?(value, field), do: to_existing_atom(value) == field

  @spec allowed_op?(any(), keyword()) :: boolean()
  defp allowed_op?(value, _field_opts) when not is_binary(value), do: false

  defp allowed_op?(value, field_opts) do
    Keyword.get(field_opts, :op, 0) == to_existing_atom(value)
  end
end
