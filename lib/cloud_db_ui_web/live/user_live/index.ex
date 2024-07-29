defmodule CloudDbUiWeb.UserLive.Index do
  use CloudDbUiWeb, :live_view
  use CloudDbUiWeb.FlashTimed, :live_view

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.UserLive.FormComponent
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket
  alias Flop.Meta

  import CloudDbUi.Accounts.User.FlopSchemaFields, [only: [sortable_fields: 0]]
  import CloudDbUiWeb.Flop
  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript
  import CloudDbUiWeb.UserLive.Actions

  @type params() :: CloudDbUi.Type.params()

  # TODO: remove
  # TODO: ?filters[0][field]=email_trimmed&filters[0][op]=ilike&filters[0][value]=&filters[1][field]=confirmed_at&filters[1][op]=not_empty&filters[1][value]=&filters[2][field]=confirmed_at&filters[2][op]=>%3D&filters[2][value]=99999-12-11T11:11&filters[3][field]=confirmed_at&filters[3][op]=<%3D&filters[3][value]=&filters[4][field]=inserted_at&filters[4][op]=>%3D&filters[4][value]=&filters[5][field]=inserted_at&filters[5][op]=<%3D&filters[5][value]=&filters[6][field]=balance_trimmed&filters[6][op]=>%3D&filters[6][value]=%20 10.00%20%20%20%20%20 &filters[7][field]=balance_trimmed&filters[7][op]=<%3D&filters[7][value]=%20 9.00%20 &filters[8][field]=active&filters[8][op]=%3D%3D&filters[8][value]=&filters[9][field]=admin&filters[9][op]=%3D%3D&filters[9][value]=&order_by[]=confirmed_at&order_by[]=balance&order_by[]=id&order_directions[]=asc&order_directions[]=asc&order_directions[]=asc&_target[]=filters&_target[]=99&_target[]=f

  @impl true
  def mount(params, _session, socket) do
    {:ok, prepare_socket(socket, params)}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: action}} = socket)
      when action in [:new, :index] do
    {:noreply, apply_action(socket, action, params)}
  end

  # Opening a modal common to `Show` and `Index` (action: `:edit`).
  def handle_params(params, _url, %{assigns: %{live_action: act}} = socket) do
    {:noreply, apply_action(socket, act, params, ~p"/users")}
  end

  @impl true
  def handle_info({FormComponent, {:saved, _user, true}}, socket) do
    {:noreply, stream_users(socket)}
  end

  def handle_info({FormComponent, {:saved, _user, false}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, filter_users(socket, params)}
  end

  def handle_event("paginate", params, socket) do
    {:noreply, paginate_users(socket, params)}
  end

  def handle_event("sort", params, socket) do
    {:noreply, sort_users(socket, params)}
  end

  def handle_event("delete", %{"id" => id} = _params, socket) do
    {:noreply, delete_user_by_id(socket, id)}
  end

  @spec prepare_socket(%Socket{}, params()) :: %Socket{}
  defp prepare_socket(socket, params) do
    prepare_socket(socket, params, connected?(socket))
  end

  @spec prepare_socket(%Socket{}, params(), boolean()) :: %Socket{}
  defp prepare_socket(socket, params, true = _connected?) do
    socket
    |> stream_users(prepare_flop(params), params)
    |> FlashTimed.clear_after()

    # TODO: remove
    #|> tap(fn a ->
    #  IO.puts("\n\n    IN mount()")
    #  IO.inspect(params)
    #  IO.puts("==========================")
    #  IO.inspect(a.assigns.meta)
    #  IO.puts("\n\n")
    #end)

  end

  defp prepare_socket(socket, _params, false) do
    socket
    |> assign(:meta, %Meta{})
    |> stream(:users, [])
  end

  @spec filter_users(%Socket{}, params()) :: %Socket{}
  defp filter_users(socket, params) do
    filter_users(socket, params, filter_users?(socket.assigns.meta, params))

    # TODO: remove
    #|> tap(fn a ->
    #  IO.puts("\n\n    IN &filter_users/2")
    #  IO.inspect(a.assigns.meta)
    #  IO.puts("\n\n")
    #end)

  end

  # A significant change in the most recently changed `type="text"`
  # input field.
  @spec filter_users(%Socket{}, params(), boolean()) :: %Socket{}
  defp filter_users(socket, %{"filters" => _filter_params} = params, true) do

    # TODO: remove
    #IO.puts("\n\n    IN &filter_users/3 WITH A SIGNIFICANT CHANGE")
    #IO.inspect(params)
    #IO.puts("\n\n")

    stream_users(
      socket,
      prepare_flop(socket.assigns.meta.flop, Map.put_new(params, "page", "1")),
      params
    )
  end

  # A non-significant change (a letter case change or an addition
  # of a trimmable whitespace) in the most recently changed input
  # `type="text"` field.
  defp filter_users(socket, %{"filters" => _} = parms, false = _filter?) do
    set_meta_params(socket, parms, filter_form_field_opts(), sortable_fields())
  end

  # Users need to be re-filtered, if any of the conditions are true:
  #
  #   - `params` have no `"_target"` key;
  #   - the value of the `"_target"` key is not a three-element list;
  #   - `target_index` is an index of an input field with the `type=""`
  #     other than `type="text"`;
  #   - the new value of the input field differs from the previous value
  #     of the same input field not just by an addition of a trimmable
  #     whitespace or a case change of a letter.
  @spec filter_users?(%Meta{}, params()) :: boolean()
  defp filter_users?(
         %Meta{} = meta,
         %{"_target" => ["filters", index, "value"] = target} = params
       ) do
    {target_index, ""} = Integer.parse(index)
    value_prev = get_meta_params_filter_value(meta, target_index)

    text_field? =
      filter_form_field_opts()
      |> Enum.at(target_index)
      |> elem(1)
      |> Keyword.fetch!(:type)
      |> Kernel.==("text")

    !text_field? or significant_change?(value_prev, get_in(params, target))
  end

  # No `"_target"` key in `params`, or its value has an unexpected shape.
  defp filter_users?(_meta, _params), do: true

  @spec paginate_users(%Socket{}, params()) :: %Socket{}
  defp paginate_users(socket, %{"page" => page} = _params) do
    if "#{socket.assigns.meta.current_page}" == page do
      # The current page link was clicked, do not query the data base.
      socket
    else
      stream_users(socket, Flop.set_page(socket.assigns.meta.flop, page))

      # TODO: remove
      #|> tap(fn a ->
      #  IO.puts("\n\n    IN paginate_users()")
      #  IO.inspect(a.assigns.meta)
      #  IO.puts("\n\n")
      #end)

    end
  end

  @spec sort_users(%Socket{}, params()) :: %Socket{}
  defp sort_users(socket, %{"order" => _order} = params) do
    stream_users(
      socket,
      maybe_push_order(socket.assigns.meta.flop, params, sortable_fields())
    )
  end

  @spec delete_user_by_id(%Socket{}, String.t()) :: %Socket{}
  defp delete_user_by_id(socket, id) when is_binary(id) do
    case "#{socket.assigns.current_user.id}" == id do
      true -> FlashTimed.put(socket, :error, "Cannot delete self.")
      false -> delete_user(socket, Accounts.get_user_with_order_count!(id))
    end
    |> case do
      %{assigns: %{flash: %{"error" => _title}}} = with_error -> with_error
      without_error -> stream_users(without_error)
    end
  end

  @spec stream_users(%Socket{}) :: %Socket{}
  defp stream_users(socket), do: stream_users(socket, socket.assigns.meta.flop)

  @spec stream_users(%Socket{}, params() | %Flop{}) :: %Socket{}
  defp stream_users(socket, params_or_flop) do
    stream_users(socket, params_or_flop, socket.assigns.meta.params)
  end

  @spec stream_users(%Socket{}, params() | %Flop{}, params()) :: %Socket{}
  defp stream_users(socket, params_or_flop, params) do
    case Accounts.list_users_with_order_count(params_or_flop) do
      {:ok, {users, meta}} ->
        socket
        |> assign(:meta, meta)
        |> stream(:users, users, reset: true)

      {:error, meta} ->
        assign(socket, :meta, meta)
    end
    |> set_meta_params(params, filter_form_field_opts(), sortable_fields())
    |> populate_meta_errors(filter_form_field_opts(), min_max_field_labels())
  end

  # A wrapper for `&CloudDbUiWeb.Flop.prepare_flop/5`.
  @spec prepare_flop(%Flop{}, params()) :: %Flop{}
  defp prepare_flop(%Flop{} = flop \\ %Flop{}, params) do
    prepare_flop(
      flop,
      params,
      filter_form_field_opts(),
      sortable_fields(),
      min_max_field_labels()
    )
  end

  @spec min_max_field_labels() :: [String.t()]
  defp min_max_field_labels() do
    [
      "Confirmed from",
      "Confirmed to",
      "Registered from",
      "Registered to",
      "Balance from",
      "Balance to"
    ]
  end

  # The value of `fields=""` for the `<.filter_form>`.
  @spec filter_form_field_opts() :: keyword(keyword())
  defp filter_form_field_opts() do
    [
      email_trimmed: text_field_opts("E-mail address", :ilike),
      confirmed_at: select_field_opts("E-mail confirmed", :not_empty),
      confirmed_at: datetime_field_opts("Confirmed from", :>=),
      confirmed_at: datetime_field_opts("Confirmed to", :<=),
      inserted_at: datetime_field_opts("Registered from", :>=),
      inserted_at: datetime_field_opts("Registered to", :<=),
      balance_trimmed: balance_field_opts(:>=),
      balance_trimmed: balance_field_opts(:<=),
      active: select_field_opts("Active"),
      admin: select_field_opts("Administrator"),
      has_orders: select_field_opts("Has orders", :!=),
      has_paid_orders: select_field_opts("Has paid orders", :!=)
    ]
  end

  @spec balance_field_opts(atom()) :: keyword()
  defp balance_field_opts(:>=) do
    decimal_field_opts("Balance from", :>=, "0.00")
  end

  defp balance_field_opts(:<=) do
    decimal_field_opts("Balance to", :<=, User.balance_limit())
  end
end
