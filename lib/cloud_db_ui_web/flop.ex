defmodule CloudDbUiWeb.Flop do
  alias CloudDbUi.Accounts.User
  alias Phoenix.LiveView.Socket
  alias Flop.{Filter, Meta}

  import CloudDbUiWeb.Utilities
  import CloudDbUi.Changeset, [only: [decimal_format_error_message: 1]]
  import CloudDbUi.FlopParamSanitiser

  @type error() :: CloudDbUi.Type.error()
  @type params() :: CloudDbUi.Type.params()

  @doc """
  Injects:

    - a function to `filter_objects()`;
    - a function to determine whether objects should be re-filtered;
    - a function to `sort_objects()`;
    - a function to `paginate_objects()`;
    - a function to `delete_object()`s;
    - a function to `maybe_filter_objects_after_deletion()`;
    - a function to determine the number of a new page of results
      to switch to after deleting an object;
    - a function to `stream_objects()` for `items=""`
      in `<Flop.Phoenix.table>`;
    - wrappers for `&prepare_flop/5`.

  `opts` must contain:

    - `:schema_field_module`, which is a module containing
      `sortable_fields()` for a `@derive` `Flop.Schema` of this
      specific object type;
    - `:stream_name`, under which the stream of objects will be placed
      in `socket.assigns.streams` (`@streams`).
  """
  @spec __using__(keyword(module() | atom())) :: Macro.t()
  defmacro __using__(opts) do
    quote do
      alias CloudDbUi.Accounts.User
      alias Phoenix.LiveView.Socket

      import CloudDbUiWeb.{Flop, Utilities}
      import unquote(opts[:schema_field_module])

      @spec filter_objects(%Socket{}, params()) :: %Socket{}
      defp filter_objects(socket, params) do
        filter_objects(
          socket,
          params,
          filter_objects?(socket, params)
        )
      end

      # A significant change in the most recently changed `type="text"`
      # input field.
      @spec filter_objects(%Socket{}, params(), boolean()) :: %Socket{}
      defp filter_objects(socket, %{"filters" => _} = params, true = _fltr?) do
        params_new = Map.put_new(params, "page", "1")

        stream_objects(socket, prepare_flop(socket, params_new), params)
      end

      # A non-significant change (a letter case change or an addition
      # of a trimmable whitespace) in the most recently changed input
      # `type="text"` field.
      defp filter_objects(
             %{assigns: %{current_user: user}} = socket,
             %{"filters" => _} = params,
             false = _need_to_filter?
           ) do
        set_meta_params(
          socket,
          params,
          filter_form_field_opts(user),
          sortable_fields()
        )
      end

      # Objects need to be re-filtered, if any of the conditions are true:
      #
      #   - `params` have no `"_target"` key;
      #   - the value of the `"_target"` key is not a three-element list;
      #   - `target_index` is an index of an input field with the `type=""`
      #     other than `type="text"`;
      #   - the new value of the input field differs from the previous
      #     value of the same input field not just by an addition
      #     of a trimmable whitespace or a case change of a letter.
      @spec filter_objects?(%Socket{}, params()) :: boolean()
      defp filter_objects?(
            %{assigns: %{meta: %Meta{} = meta}} = socket,
            %{"_target" => ["filters", index, "value"] = target} = params
          ) do
        {target_index, ""} = Integer.parse(index)
        value_prev = get_meta_params_filter_value(meta, target_index)

        text_field? =
          socket.assigns.current_user
          |> filter_form_field_opts()
          |> Enum.at(target_index)
          |> elem(1)
          |> Keyword.fetch!(:type)
          |> Kernel.==("text")

        !text_field? or significant_change?(value_prev, get_in(params, target))
      end

      # No `"_target"` key in `params`, or its value has an unexpected shape.
      defp filter_objects?(_socket, _params), do: true

      @spec sort_objects(%Socket{}, params()) :: %Socket{}
      defp sort_objects(socket, %{"order" => _order} = params) do
        stream_objects(
          socket,
          maybe_push_order(socket.assigns.meta.flop, params, sortable_fields())
        )
      end

      @spec paginate_objects(%Socket{}, params()) :: %Socket{}
      defp paginate_objects(socket, %{"page" => page} = _params) do
        if "#{socket.assigns.meta.current_page}" == page do
          # The current page link was clicked, do not query the data base.
          socket
        else
          stream_objects(socket, Flop.set_page(socket.assigns.meta.flop, page))
        end
      end

      @spec delete_object(%Socket{}, String.t()) :: %Socket{}
      defp delete_object(%{assigns: %{meta: meta}} = socket, id) do
        socket
        |> delete_object_by_id(id)
        |> maybe_filter_objects_after_deletion()
      end

      # The deletion failed (an `"error"` in `socket.assigns.flash`).
      @spec maybe_filter_objects_after_deletion(%Socket{}) :: %Socket{}
      defp maybe_filter_objects_after_deletion(
             %{assigns: %{flash: %{"error" => _}}} = socket
           ) do
        socket
      end

      # No `"error"` in `socket.assigns.flash`.
      defp maybe_filter_objects_after_deletion(socket) do
        maybe_filter_objects_after_deletion(
          socket,
          page_number_after_deletion(socket)
        )
      end

      @spec maybe_filter_objects_after_deletion(%Socket{}, nil) :: %Socket{}
      defp maybe_filter_objects_after_deletion(socket, nil) do
        update(
          socket,
          :meta,
          &Map.replace!(&1, :total_count, &1.total_count - 1)
        )
      end

      @spec maybe_filter_objects_after_deletion(%Socket{}, pos_integer()) ::
              %Socket{}
      defp maybe_filter_objects_after_deletion(socket, page) do
        stream_objects(socket, Flop.set_page(socket.assigns.meta.flop, page))
      end

      # Objects need to be re-filtered after deleting one of them,
      # if any of the conditions are true:
      #
      #   - the deleton succeeded (there is no `:error` flash);
      #   - the current_page is not the last page (a full page of results);
      #     re-filter on the same page;
      #   - the current page is the last page with only one result on it
      #     before the deletion; switch to the previous page and re-filter.
      #
      # If re-filtering is necessary, return the number of a page
      # to switch to (even if it is the same page). Otherwise, return `nil`.
      @spec page_number_after_deletion(%Socket{}) :: pos_integer() | nil
      defp page_number_after_deletion(%{assigns: %{meta: meta}} = socket) do
        cond do
          Phoenix.Flash.get(socket.assigns.flash, :error) -> nil
          meta.current_page != meta.total_pages -> meta.current_page
          result_count_on_page(meta) == 1 -> meta.current_page - 1
          true -> nil
        end
      end

      @spec stream_objects(%Socket{}) :: %Socket{}
      defp stream_objects(socket) do
        stream_objects(socket, socket.assigns.meta.flop)
      end

      @spec stream_objects(%Socket{}, %Flop{}) :: %Socket{}
      defp stream_objects(socket, %Flop{} = flop) do
        stream_objects(socket, flop, socket.assigns.meta.params)
      end

      @spec stream_objects(%Socket{}, %Flop{}, params()) :: %Socket{}
      defp stream_objects(
             %{assigns: %{current_user: user}} = socket,
             %Flop{} = flop,
             params
           ) do
        flop
        |> list_objects(user)
        |> case do
          {:ok, {objects, meta}} ->

            # TODO: remove
            #IO.puts("\n\n    IN stream_objects()")
            real_total = length(objects)
            if meta.next_offset && real_total != meta.next_offset - meta.current_offset do
              missing_count = meta.next_offset - meta.current_offset - real_total
              #IO.puts("BUGGED, MISSING #{missing_count}")
              #IO.puts("==========================")
            end
            #on_last_page=rem(length(objects), meta.page_size)
            #total_pages=case on_last_page do
            #  0 -> div(length(objects), meta.page_size)
            #  _non_zero -> div(length(objects), meta.page_size) + 1
            #end
            #meta=meta|>Map.replace!(:total_count, length(objects))|>Map.replace!(:total_pages, total_pages)
            #IO.inspect(Enum.map(objects, & &1.id))
            #IO.puts("============================")
            #IO.inspect(meta)
            #IO.puts("\n\n")

            socket
            |> assign(:meta, meta)
            |> stream(unquote(opts[:stream_name]), objects, reset: true)

          {:error, meta} ->
            assign(socket, :meta, meta)
        end
        |> set_meta_params(
          params,
          filter_form_field_opts(user),
          sortable_fields()
        )
        |> populate_meta_errors(
          filter_form_field_opts(user),
          min_max_field_labels()
        )
      end

      # Wrappers for `&CloudDbUiWeb.Flop.prepare_flop/5`.
      @spec prepare_flop(%Socket{}, params()) :: %Flop{}
      defp prepare_flop(%{assigns: %{meta: meta}} = socket, params) do
        prepare_flop(meta.flop, params, socket.assigns.current_user)
      end

      # No `:meta` key in `socket.assigns`.
      defp prepare_flop(socket, params) do
        prepare_flop(%Flop{}, params, socket.assigns.current_user)
      end

      @spec prepare_flop(%Flop{}, params(), %User{}) :: %Flop{}
      defp prepare_flop(%Flop{} = flop, params, user) do
        prepare_flop(
          flop,
          params,
          filter_form_field_opts(user),
          sortable_fields(),
          min_max_field_labels()
        )
      end
    end
  end

  @doc """
  Create or change a `%Flop{}`: set `:filters`, `Flop.push_order()`,
  `Flop.set_page()` from `params`. Internally trim `:value`s of filters
  corresponding to `type="text"` input fields. Validate `:values`
  of `%Filter{}`s corresponding to `type="text" inputmode="decimal"`,
  to `type="datetime-local"`, to `<select>` input fields and to any paired
  "from"-"to" input fields: if the `:value` is invalid, replace it
  with `nil` internally, allowing the query to treat filter form input
  fields with an invalid value as if they were blank.
  """
  @spec prepare_flop(
          %Flop{},
          params(),
          keyword(keyword()),
          [atom()],
          [{String.t(), String.t()}]
        ) :: %Flop{}
  def prepare_flop(flop, params, form_field_opts, sortable, min_max_labels) do
    params_new = sanitise_params(params, form_field_opts, sortable)

    flop
    |> maybe_set_filters(params_new, form_field_opts)
    |> maybe_push_order(params_new, sortable)
    |> maybe_set_page(params_new)
    |> maybe_replace_decimal_filter_values(form_field_opts)
    |> maybe_replace_datetime_filter_values(form_field_opts)
    |> maybe_replace_min_max_filter_values(form_field_opts, min_max_labels)
    |> maybe_replace_select_filter_values(form_field_opts)
  end

  @doc """
  Populate `socket.assigns.meta.errors` with filter input validation errors.
  """
  @spec populate_meta_errors(
          %Socket{},
          keyword(keyword()),
          [{String.t(), String.t()}]
        ) :: %Socket{}
  def populate_meta_errors(socket, form_field_opts, min_max_labels) do
    socket
    |> maybe_add_decimal_errors(form_field_opts)
    |> maybe_add_datetime_errors(form_field_opts)
    |> maybe_add_min_max_errors(form_field_opts, min_max_labels)
  end

  @doc """
  Get the value corresponding to the `"value"` key
  from the `params["filters"]` list element at `index`.

  `:params` in a `%Meta{}` have the following shape:
  `%{"filters" => [%{"field" => "a", "op" => "==", "value" => ""}]}`.
  """
  @spec get_meta_params_filter_value(%Meta{}, non_neg_integer()) :: String.t()
  def get_meta_params_filter_value(%Meta{params: params} = _meta, index) do
    params
    |> Map.get("filters", [])
    |> Enum.at(index, %{})
    |> Map.get("value", "")
  end

  @doc """
  Set `socket.assigns.meta.params` from passed `params`.
  If `socket.assigns.meta.params` is left as an empty map, filter form
  input fields will not be able to output any errors.
  """
  @spec set_meta_params(%Socket{}, params(), keyword(keyword()), [atom()]) ::
          %Socket{}
  def set_meta_params(socket, params, form_field_opts, sortable_fields) do
    params_new =
      params
      |> sanitise_params(form_field_opts, sortable_fields)
      |> Map.replace_lazy("filters", fn filter_params ->
        if is_map(filter_params) do
          filter_params
          |> to_sorted_list()
          |> Enum.map(&elem(&1, 1))
        else
          filter_params
        end
      end)

    Phoenix.Component.update(socket, :meta, fn meta ->
      Map.update!(meta, :params, &Map.merge(&1, params_new))
    end)
  end

  @doc """
  Call `Flop.push_order()` if `params` contain `"order"`. If `params`
  do not contain `"order"`, but contain `"order_by"` (and maybe
  `"order_directions"`), directly replace corresponding fields
  in the `flop`.
  """
  @spec maybe_push_order(%Flop{}, params(), [atom()]) :: %Flop{}
  def maybe_push_order(flop, params, sortable_fields) do
    maybe_push_order(flop, params, sortable_fields, [])
  end

  @spec maybe_push_order(%Flop{}, params(), [atom()], keyword()) :: %Flop{}
  def maybe_push_order(flop, %{"order" => _} = params, sortable, opts) do
    Flop.push_order(
      flop,
      sanitise_order_params(params, sortable)["order"],
      opts
    )
  end

  def maybe_push_order(flop, %{"order_by" => _by} = params, sortable, _opts) do
    params_new = sanitise_order_params(params, sortable)

    flop
    |> Map.replace!(:order_by, params_new["order_by"])
    |> Map.replace!(:order_directions, params_new["order_directions"])
  end

  # No `"order"` and no `"order_by"` in `params`.
  def maybe_push_order(flop, _params, _sortable_fields, _opts), do: flop

  @doc """
  Return the count of results displayed on the current page.
  For a non-last page, this count will be equal to `meta.page_size`.
  """
  @spec result_count_on_page(%Meta{}) :: non_neg_integer()
  def result_count_on_page(%Meta{} = meta)
      when meta.current_page > meta.total_pages do
    0
  end

  # A non-last page (attempts to set a negative page are handled
  # correctly by Flop itself).
  def result_count_on_page(%Meta{} = meta)
      when meta.current_page < meta.total_pages do
    meta.page_size
  end

  # The last page.
  def result_count_on_page(%Meta{} = meta)
      when meta.current_page == meta.total_pages do
    case rem(meta.total_count, meta.page_size) do
      0 -> meta.page_size
      remainder -> remainder
    end
  end

  @doc """
  Options of a `type="text"` filter field without `inputmode="decimal"`.
  """
  @spec text_field_opts(String.t(), atom()) :: keyword()
  def text_field_opts(label, op \\ :ilike) do
    [op: op, label: label, type: "text"]
  end

  @doc """
  Options of a `type="text"` input field for a decimal schema field
  to support trimmable whitespaces.
  """
  @spec decimal_field_opts(String.t(), atom(), any()) :: keyword()
  def decimal_field_opts(label, op, placeholder) do
    label
    |> decimal_field_opts(op)
    |> Keyword.put_new(:placeholder, placeholder)
  end

  @spec decimal_field_opts(String.t(), atom()) :: keyword()
  def decimal_field_opts(label, op \\ :==) do
    [op: op, label: label, type: "text", inputmode: "decimal"]
  end

  @doc """
  Options of a `type="datetime-local"` input field.
  """
  @spec datetime_field_opts(String.t(), atom()) :: keyword()
  def datetime_field_opts(label, op \\ :==) do
    [op: op, label: label, type: "datetime-local"]
  end

  @doc """
  Options of a `<select>` filter field that is useful when a boolean
  schema field is not expected to have a `nil` value, thus a check box
  cannot be used, as unchecking it filters by `false` instead of clearing
  the filter.
  """
  @spec select_field_opts(String.t(), atom(), [{String.t(), any()}]) ::
          keyword()
  def select_field_opts(
        label,
        op \\ :==,
        opts \\ [{"Yes", true}, {"No", false}]
      ) do
    [op: op, label: label, type: "select", prompt: "—", options: opts]
  end

  @doc """
  Check whether any fields of the `updated` object that have a changed
  value compared to the `original` object are in `refilter_trigger_fields`.
  """
  @spec refilter?(struct(), struct(), [atom()]) :: boolean()
  def refilter?(original, updated, refilter_trigger_fields) do
    original
    |> Map.filter(fn {key, val} -> Map.fetch!(updated, key) != val end)
    |> Map.keys()
    |> Enum.any?(&(&1 in refilter_trigger_fields))
  end

  @doc """
  Make the error text laconic, for example, to be outputted
  as an in-line error next to a `<.label>`.
  """
  @spec shorten_error_text(error()) :: error()
  def shorten_error_text({text, extra_info} = _error) do
    over_limit_error = "must be less than or equal to #{User.balance_limit}"

    text_new =
      case text do
        "is invalid" -> "invalid"
        "invalid format; valid examples: 5, 7.9, 12.99" -> "format"
        ^over_limit_error -> "> #{User.balance_limit}"
        "negative zero is not allowed" -> "negative"
        "must not be negative" -> "negative"
        "can't be in the future" -> "future"
        "too far in the past" -> "far past"
        "can't be larger than \"to\"" -> "> \"to\""
        "can't be smaller than \"from\"" -> "< \"from\""
        any -> any
      end

    {text_new, extra_info}
  end

  # For filters corresponding to a `type="text" inputmode="decimal"`
  # field, replace a non-`nil` filter `:value` with `nil`, if any condition
  # is true:
  #
  #  - the `:value` is not fully parsable as a `%Decimal{}`;
  #  - the `:value` does not represent a `valid_number_format?()`
  #    with no more than two decimal places;
  #  - the `:value` represents a negative zero;
  #  - the `:value` represents a negative number;
  #  - the `:value` represents a number larger than `User.balance_limit()`.
  @spec maybe_replace_decimal_filter_values(%Flop{}, keyword(keyword())) ::
          %Flop{}
  defp maybe_replace_decimal_filter_values(%Flop{} = flop, form_field_opts) do
    maybe_replace_filter_values(
      flop,
      decimal_field_indices(form_field_opts),
      &maybe_replace_decimal_filter_value/1
    )
  end

  @spec maybe_replace_decimal_filter_value(%Filter{}) :: %Filter{}
  defp maybe_replace_decimal_filter_value(%Filter{value: value} = filter) do
    value
    |> maybe_get_decimal_error()
    |> case do
      nil -> filter
      _any_error -> Map.replace!(filter, :value, nil)
    end
  end

  # For filters corresponding to a `type="datetime-local"` field, replace
  # any invalid (or valid, but in the future) ISO 8601 date and time string
  # representation in the filter `:value` with `nil`.
  # This is necessary in order to avoid `[debug] Invalid Flop` errors.
  # The query will treat a `type="datetime-local"` input field
  # with an invalid value as if it was blank.
  @spec maybe_replace_datetime_filter_values(%Flop{}, keyword(keyword())) ::
          %Flop{}
  defp maybe_replace_datetime_filter_values(%Flop{} = flop, form_field_opts) do
    maybe_replace_filter_values(
      flop,
      datetime_field_indices(form_field_opts),
      &maybe_replace_datetime_filter_value/1
    )
  end

  # Replace `filter.value` with `nil` in any of the following cases:
  #
  #   - `:value` is not a valid ISO 8601 date and time string representation;
  #   - `:value` is a representation of `%DateTime{}` that is in the future;
  #   - `:value` is a representation of `%DateTime{}` that is before
  #     the Unix start time.
  @spec maybe_replace_datetime_filter_value(%Filter{}) :: %Filter{}
  defp maybe_replace_datetime_filter_value(%Filter{value: value} = filter) do
    "#{value}:00Z"
    |> DateTime.from_iso8601()
    |> case do
      {:ok, %DateTime{} = dt, 0} ->
        case maybe_get_datetime_error(dt) do
          nil -> filter
          _any -> Map.replace!(filter, :value, nil)
        end

      {:error, _reason} ->
        Map.replace!(filter, :value, nil)
    end
  end

  # For each pair or filters corresponding to paired "from"-"to" fields,
  # replace both `:value`s with `nil`, if the `:value` of the "from" field
  # filter is greater than the `:value` of the "to" field filter.
  # The query will treat both of these input fields as if they were blank.
  @spec maybe_replace_min_max_filter_values(
          %Flop{},
          keyword(keyword()),
          [{String.t(), String.t()}]
        ) :: %Flop{}
  defp maybe_replace_min_max_filter_values(flop, form_field_opts, mm_labels) do
    Map.update!(flop, :filters, fn filters ->
      mm_labels
      |> min_max_field_indices(form_field_opts)
      |> Enum.reduce(filters, fn {i_from, i_to}, acc ->
        filters
        |> to_date_time_or_to_decimal(i_from)
        |> maybe_get_min_max_errors(to_date_time_or_to_decimal(filters, i_to))
        |> case do
          {nil, nil} -> acc
          _errs -> replace_min_max_filter_values(acc, [i_from, i_to])
        end
      end)
    end)
  end

  # Replace the `:value` of `%Filter{}s` at `indices` with `nil`.
  @spec replace_min_max_filter_values([%Filter{}], [non_neg_integer()]) ::
          [%Filter{}]
  defp replace_min_max_filter_values(filters, indices) when is_list(filters) do
    Enum.reduce(indices, filters, fn index, acc ->
      List.update_at(acc, index, &Map.replace!(&1, :value, nil))
    end)
  end

  # For filters corresponding to a `<select>` field, replace the filter
  # `:value` with `nil`, if the `:value` of a `filter` is not one
  # of string-converted values in corresponding `:options`
  # of `form_field_opts`.
  # The query will treat this `<select>` field as if it has a default
  # option chosen.
  @spec maybe_replace_select_filter_values(%Flop{}, keyword(keyword())) ::
          %Flop{}
  defp maybe_replace_select_filter_values(flop, form_field_opts) do
    maybe_replace_filter_values(
      flop,
      select_field_indices(form_field_opts),
      &maybe_replace_select_filter_value(&1, form_field_opts, &2)
    )
  end

  @spec maybe_replace_select_filter_value(
          %Filter{},
          keyword(keyword()),
          non_neg_integer()
        ) :: %Filter{}
  defp maybe_replace_select_filter_value(filter, form_field_opts, index) do
    converted_options =
      form_field_opts
      |> Enum.at(index)
      |> elem(1)
      |> Keyword.fetch!(:options)
      |> Enum.map(&"#{elem(&1, 1)}")

    case Map.fetch!(filter, :value) in converted_options do
      true -> filter
      false -> Map.replace!(filter, :value, nil)
    end
  end

  @spec maybe_add_meta_errors(
          %Socket{},
          [non_neg_integer()],
          (%Meta{}, non_neg_integer() -> %Meta{})
        ) :: %Socket{}
  defp maybe_add_meta_errors(socket, indices, fn_add_error) do
    Phoenix.Component.update(socket, :meta, fn meta ->
      Enum.reduce(indices, meta, fn indx, acc -> fn_add_error.(acc, indx) end)
    end)
  end

  # Validate a non-blank filter `value` corresponding to each
  # `type="text" inputmode="decimal"` input field by converting it
  # to a `%Decimal{}`. The possible errors are:
  #
  #   - "invalid format; valid examples: 5, 7.9, 12.99" if the `value`
  #     does not represent a `valid_number_format?()` with no more than two
  #     decimal places;
  #   - "negative zero is not allowed" for `%Decimal{coef: 0, sign: -1}`;
  #   - "must not be negative" for `%Decimal{sign: -1}`;
  #   - "must be less than or equal to N", where N is `User.balance_limit()`;
  #   - "is invalid" for a `value` not parsable as a `%Decimal{}`.
  @spec maybe_add_decimal_errors(%Socket{}, keyword(keyword())) ::
          %Socket{}
  defp maybe_add_decimal_errors(socket, form_field_opts) do
    maybe_add_meta_errors(
      socket,
      decimal_field_indices(form_field_opts),
      &maybe_add_decimal_error/2
    )
  end

  # Validate a non-blank URL parameter `"value"` corresponding to each
  # `type="datetime-local"` input field by converting it to a `%DateTime{}`.
  # The possible errors are:
  #
  #   - "can't be in the future" for a `%DateTime{}` in the future;
  #   - "is invalid" for a `value` not convertible to a `%DateTime`
  #     via `DateTime.from_iso8601()`.
  @spec maybe_add_datetime_errors(%Socket{}, keyword(keyword())) ::
          %Socket{}
  defp maybe_add_datetime_errors(socket, form_field_opts) do
    maybe_add_meta_errors(
      socket,
      datetime_field_indices(form_field_opts),
      &maybe_add_datetime_error/2
    )
  end

  # Validate a non-blank input field `"value"` corresponding to each
  # of the passed input field indices (both input fields are assumed
  # to have the same type) by comparing them. The possible errors
  # will be added to both fields:
  #
  #   - "can't be larger than \"to\"", if the `"value"` of the field
  #     corresponding to the `index_from` is larger than the `"value"`
  #     of the field corresponding to the `index_to`;
  #   - "can't be smaller than \"from\"", if the `"value"` of the field
  #     corresponding to the `index_to` is smaller than the `"value"`
  #     of the field corresponding to the `index_from`.
  @spec maybe_add_min_max_errors(
          %Socket{},
          keyword(keyword()),
          [{String.t(), String.t()}]
        ) :: %Socket{}
  defp maybe_add_min_max_errors(socket, form_field_opts, min_max_labels) do
    Phoenix.Component.update(socket, :meta, fn meta ->
      min_max_labels
      |> min_max_field_indices(form_field_opts)
      |> Enum.reduce(meta, fn {index_from, index_to}, acc ->
        case maybe_get_min_max_errors(acc, index_from, index_to) do
          {nil, nil} ->
            acc

          {error_from, error_to} ->
            acc
            |> add_meta_error(index_from, error_from, :from_smaller)
            |> add_meta_error(index_to, error_to, :to_larger)
        end
      end)
    end)
  end

  # Set the value of the `:filters` field of a `%Flop{}`, if passed params
  # contain `"filters"`. Each element of the value under `"filters"`
  # gets converted into a `%Filter{}`.
  @spec maybe_set_filters(%Flop{}, params(), keyword(keyword())) :: %Flop{}
  defp maybe_set_filters(flop, %{"filters" => filters}, form_field_opts) do
    Map.update!(flop, :filters, fn _ ->
      form_field_opts
      |> Enum.with_index()
      |> Enum.map(fn {{field, field_opts}, index} ->
        case is_map(filters) do
          true -> filters["#{index}"]["value"]
          false -> Enum.at(filters, index)["value"]
        end
        |> case do
          "" -> %Filter{field: field, op: field_opts[:op] || :==, value: nil}
          any -> %Filter{field: field, op: field_opts[:op] || :==, value: any}
        end
      end)
    end)
  end

  # No `"filters"` in `params`.
  defp maybe_set_filters(flop, _params, _form_field_opts), do: flop

  # Call `Flop.set_page()` if `params` contain `"page"`.
  @spec maybe_set_page(%Flop{}, params()) :: %Flop{}
  defp maybe_set_page(flop, %{"page" => _} = params) do
    Flop.set_page(flop, sanitise_page_params(params)["page"])
  end

  # No `"page"` in `params`.
  defp maybe_set_page(flop, _params), do: flop

  @spec maybe_replace_filter_values(
          %Flop{},
          [non_neg_integer()],
          (%Filter{}, non_neg_integer() -> %Filter{}) | (%Filter{} -> %Filter{})
        ) :: %Flop{}
  defp maybe_replace_filter_values(%Flop{} = flop, indices, fn_replace)
       when is_function(fn_replace, 1) do
    maybe_replace_filter_values(
      flop,
      indices,
      fn filter, _index -> fn_replace.(filter) end
    )
  end

  defp maybe_replace_filter_values(%Flop{} = flop, indices, fn_replace) do
    Map.update!(flop, :filters, fn filters ->
      Enum.reduce(indices, filters, fn index, acc ->
        List.update_at(acc, index, &fn_replace.(&1, index))
      end)
    end)
  end

  @spec maybe_add_decimal_error(%Meta{}, non_neg_integer()) :: %Meta{}
  defp maybe_add_decimal_error(%Meta{} = meta, filter_index) do
    meta
    |> get_meta_params_filter_value(filter_index)
    |> maybe_get_decimal_error()
    |> case do
      nil -> meta
      error_text -> add_meta_error(meta, filter_index, error_text)
    end
  end

  @spec maybe_get_decimal_error(String.t() | nil) :: String.t() | nil
  defp maybe_get_decimal_error(nil), do: nil

  defp maybe_get_decimal_error(value) when is_binary(value) do
    case String.trim(value) do
      "" ->
        nil

      trimmed ->
        parse_result = parse_decimal(trimmed)

        cond do
          parse_result == :error -> "is invalid"
          elem(parse_result, 1) != "" -> "is invalid"
          !valid_number_format?(trimmed, 2) -> decimal_format_error_message(2)
          true -> maybe_get_decimal_error(elem(parse_result, 0))
        end
    end
  end

  @spec maybe_get_decimal_error(%Decimal{}) :: String.t() | nil
  defp maybe_get_decimal_error(%Decimal{} = parsed) do
    case parsed do
      %Decimal{coef: 0, sign: -1} ->
        "negative zero is not allowed"

      %Decimal{sign: -1} ->
        "must not be negative"

      %Decimal{sign: 1} ->
        if Decimal.compare(parsed, User.balance_limit()) == :gt do
          "must be less than or equal to #{User.balance_limit()}"
        end
    end
  end

  # Check that a string `value` is a valid ISO 8601 date and time
  # representation that is not in the future and not too far in the past
  # (not before the Unix start time).
  # If the first call of `DateTime.from_iso8601()` returns an error,
  # shorten the year representation to no more than four characters
  # and call `DateTime.from_iso8601()` again. If the second call also
  # fails, do not add an error, because a `type="datetime-local"` input
  # field will not be able to keep such a value and will be cleared out
  # anyway.
  # Note that a `type="datetime-local"` input field can hold a value
  # like `"111111-12-12T11:11"`, even though it is not a valid ISO 8601
  # date and time representation.
  @spec maybe_add_datetime_error(%Meta{}, non_neg_integer()) :: %Meta{}
  defp maybe_add_datetime_error(meta, filter_index) do
    maybe_add_datetime_error(
      meta,
      filter_index,
      get_meta_params_filter_value(meta, filter_index)
    )
  end

  @spec maybe_add_datetime_error(%Meta{}, non_neg_integer(), String.t()) ::
          %Meta{}
  defp maybe_add_datetime_error(meta, _filter_index, ""), do: meta

  defp maybe_add_datetime_error(%Meta{} = meta, filter_index, value) do
    "#{value}:00Z"
    |> DateTime.from_iso8601()
    |> case do
      {:ok, %DateTime{} = dt, 0} ->
        case maybe_get_datetime_error(dt) do
          nil -> meta
          error -> add_meta_error(meta, filter_index, error)
        end

      {:error, _reason} ->
        "#{value}:00Z"
        |> String.replace(~r/^\d+(?=-)/, String.slice(value, 0, 4))
        |> DateTime.from_iso8601()
        |> case do
          {:ok, %DateTime{}, 0} ->
            add_meta_error(meta, filter_index, "is invalid")

          {:error, _reason} ->
            # The input field cannot hold such a value anyway - no error.
            meta
        end
    end
  end

  # Does not include the "is invalid" error.
  @spec maybe_get_datetime_error(%DateTime{}) :: String.t() | nil
  defp maybe_get_datetime_error(dt) do
    cond do
      DateTime.compare(dt, DateTime.utc_now()) == :gt ->
        "can't be in the future"

      DateTime.compare(dt, DateTime.from_unix!(0)) == :lt ->
        "too far in the past"

      true ->
        nil
    end
  end

  @spec maybe_get_min_max_errors(
          %Meta{},
          non_neg_integer(),
          non_neg_integer()
        ) :: {String.t(), String.t()} | {nil, nil}
  defp maybe_get_min_max_errors(%Meta{} = meta, index_from, index_to)
       when index_from != index_to do
    if has_meta_error?(meta, index_from) or has_meta_error?(meta, index_to) do
      {nil, nil}
    else
      maybe_get_min_max_errors(
        to_date_time_or_to_decimal(meta, index_from),
        to_date_time_or_to_decimal(meta, index_to)
      )
    end
  end

  @spec maybe_get_min_max_errors(
          %DateTime{} | %Decimal{} | nil,
          %DateTime{} | %Decimal{} | nil
        ) :: {String.t(), String.t()} | {nil, nil}
  defp maybe_get_min_max_errors(nil, _value_to), do: {nil, nil}

  defp maybe_get_min_max_errors(_value_from, nil), do: {nil, nil}

  defp maybe_get_min_max_errors(value_from, value_to) do
    case value_from.__struct__.compare(value_from, value_to) == :gt do
      true -> {"can't be larger than \"to\"", "can't be smaller than \"from\""}
      false -> {nil, nil}
    end
  end

  @spec add_meta_error(%Meta{}, non_neg_integer(), String.t() | nil) :: %Meta{}
  defp add_meta_error(%Meta{} = meta, filter_index, msg) do
    add_meta_error(meta, filter_index, msg, nil)
  end

  # Do not add a meta error, if the `msg` is `nil`.
  @spec add_meta_error(%Meta{}, non_neg_integer(), nil, atom() | nil) ::
          %Meta{}
  defp add_meta_error(%Meta{} = meta, _, nil = _msg, _validation), do: meta

  # Add an error for a specific `filter_index` in a `%Meta{}`.
  @spec add_meta_error(%Meta{}, non_neg_integer(), String.t(), atom() | nil) ::
          %Meta{}
  defp add_meta_error(%Meta{} = meta, filter_index, msg, validation) do
    Map.update!(meta, :errors, fn errors ->
      errors
      |> Keyword.put_new_lazy(:filters, fn ->
        List.duplicate([], length(meta.flop.filters))
      end)
      |> Keyword.update!(:filters, fn filter_errors ->
        add_meta_error(filter_errors, filter_index, msg, validation)
      end)
    end)
  end

  # The first argument is `meta.errors[:filters]` of a struct like
  # `%Meta{errors: [filters: [[], [value: [{"error_text", []}]], []]]}`.
  @spec add_meta_error(
          [keyword([error()])],
          non_neg_integer(),
          String.t(),
          atom() | nil
        ) :: [keyword([error()])]
  defp add_meta_error(filter_errors, filter_index, msg, validation) do
    error_new =
      case validation do
        nil -> {msg, []}
        any -> {msg, [validation: any]}
      end

    List.update_at(filter_errors, filter_index, fn errors_for_filter ->
      Keyword.update(errors_for_filter, :value, [error_new], fn value_errors ->
        [error_new | value_errors]
      end)
    end)
  end

  # Check whether any error for a specific `filter_index` exists
  # in a `%Meta{}`.
  @spec has_meta_error?(%Meta{}, non_neg_integer()) :: boolean()
  defp has_meta_error?(%Meta{} = meta, filter_index) do
    meta
    |> get_filter_value_errors(filter_index)
    |> case do
      [] -> false
      _any -> true
    end
  end

  # Given `%Meta{errors: [filters: [[], [value: [{"error", []}]], []]]}`,
  # take the element at `filter_index` of the list under `:filters`
  # and from it retrieve the list of errors under `:value`.
  @spec get_filter_value_errors(%Meta{}, non_neg_integer()) :: [error()]
  defp get_filter_value_errors(%Meta{} = meta, filter_index) do
    meta.errors
    |> Keyword.get(:filters, [])
    |> Enum.at(filter_index, [])
    |> Keyword.get(:value, [])
  end

  # Get indices of `<select>` input fields.
  # `form_field_opts` are what is passed into `Flop.Phoenix.filter_fields`
  # as `fields={}`.
  @spec select_field_indices(keyword(keyword())) :: [non_neg_integer()]
  defp select_field_indices(form_field_opts) do
    field_indices(form_field_opts, &(&1[:type] == "select"))
  end

  # Get indices of `type="text" inputmode="decimal"` input fields.
  # `form_field_opts` are what is passed into `Flop.Phoenix.filter_fields`
  # as `fields={}`.
  @spec decimal_field_indices(keyword(keyword())) :: [non_neg_integer()]
  defp decimal_field_indices(form_field_opts) do
    field_indices(
      form_field_opts,
      &(&1[:type] == "text" and &1[:inputmode] == "decimal")
    )
  end

  # Get indices of `type="datetime-local"` input fields.
  # `form_field_opts` are what is passed into `Flop.Phoenix.filter_fields`
  # as `fields={}`.
  @spec datetime_field_indices(keyword(keyword())) :: [non_neg_integer()]
  defp datetime_field_indices(form_field_opts) do
    field_indices(form_field_opts, &(&1[:type] == "datetime-local"))
  end

  # Get indices of "from"/"to" paired input fields.
  # `form_field_opts` are what is passed into `Flop.Phoenix.filter_fields`
  # as `fields={}`.
  @spec min_max_field_indices(
          [{String.t(), String.t()}],
          keyword(keyword())
        ) :: [{non_neg_integer(), non_neg_integer()}]
  defp min_max_field_indices(input_field_paired_labels, form_field_opts) do
    input_field_paired_labels
    |> Enum.map(fn {label_from, label_to} ->
      {
        find_field_index(form_field_opts, label_from),
        find_field_index(form_field_opts, label_to)
      }
    end)
    |> Enum.reject(fn {index_from, index_to} ->
      !index_from or !index_to
    end)
  end

  # Get the index of a filter input field with a `:label` matching
  # `input_field_label_text`.
  @spec find_field_index(keyword(keyword()), String.t()) ::
          non_neg_integer() | nil
  defp find_field_index(form_field_opts, input_field_label_text) do
    form_field_opts
    |> field_indices(&(&1[:label] == input_field_label_text))
    |> List.first()
  end

  # `form_field_opts` are what is passed into `Flop.Phoenix.filter_fields`
  # as `fields={}`.
  @spec field_indices(keyword(keyword()), (keyword() -> boolean())) ::
          [non_neg_integer()]
  defp field_indices(form_field_opts, fn_condition) do
    form_field_opts
    |> Enum.with_index()
    |> Enum.filter(fn {{_field, opts}, _index} -> fn_condition.(opts) end)
    |> Enum.map(&elem(&1, 1))
  end

  @spec to_date_time_or_to_decimal(%Meta{} | [%Filter{}], non_neg_integer()) ::
          %DateTime{} | %Decimal{} | nil
  defp to_date_time_or_to_decimal(%Meta{} = meta, index) do
    meta
    |> get_meta_params_filter_value(index)
    |> to_date_time_or_to_decimal()
  end

  defp to_date_time_or_to_decimal(filters, index) do
    filters
    |> Enum.at(index, %Filter{})
    |> Map.fetch!(:value)
    |> to_date_time_or_to_decimal()
  end

  @spec to_date_time_or_to_decimal(String.t() | nil) ::
          %DateTime{} | %Decimal{} | nil
  defp to_date_time_or_to_decimal(value) do
    trimmed = String.trim("#{value}")

    cond do
      trimmed == "" ->
        nil

      String.contains?(trimmed, ["T", " "]) ->
        case DateTime.from_iso8601(value <> ":00Z") do
          {:ok, dt, 0} -> dt
          _any -> nil
        end

      true ->
        case parse_decimal(trimmed) do
          {parsed, ""} -> parsed
          _error_or_not_fully_parsed -> nil
        end
    end
  end
end
