defmodule CloudDbUi.Orders.Order.FlopSchemaFields do
  use CloudDbUi.FlopSchemaFields

  @impl true
  @spec filterable_fields() :: [atom()]
  def filterable_fields() do
    [
      :user_email_trimmed,
      :product_name_trimmed,
      :inserted_at,
      :total_filterable_trimmed,
      :paid_at,
      :paid
    ]
  end

  @impl true
  @spec sortable_fields() :: [atom()]
  def sortable_fields() do
    [
      :id,
      :user_id,
      :total_sortable,
      :inserted_at,
      :paid_at
    ]
  end

  @impl true
  @spec adapter_opts() :: keyword([atom() | keyword(keyword())])
  def adapter_opts() do
    [
      alias_fields: [:total_sortable],
      custom_fields: custom_field_opts(),
      join_fields: join_field_opts()
    ]
  end

  # The `%User{}` is an administrator, can see any orders.
  @impl true
  @spec list_objects(%Flop{}, %User{} | nil) ::
          {:ok, {[struct()], %Flop.Meta{}}} | {:error, %Flop.Meta{}}
  def list_objects(%Flop{} = flop, %User{admin: true}) do
    CloudDbUi.Orders.list_orders_with_full_preloads(flop)
  end

  # The `%User{}` is not an administrator, can see only own orders.
  def list_objects(%Flop{} = flop, user) do
    CloudDbUi.Orders.list_orders_with_suborder_products(flop, user)
  end

  @impl true
  @spec delete_object_by_id(%Socket{}, String.t()) :: %Socket{}
  def delete_object_by_id(socket, id) do
    CloudDbUiWeb.OrderLive.Actions.delete_order!(
      socket,
      CloudDbUi.Orders.get_order_with_suborder_ids!(id)
    )
  end

  @impl true
  @spec min_max_field_labels() :: [{String.t(), String.t()}]
  def min_max_field_labels() do
    [
      {"Created from", "Created to"},
      {"Total from", "Total to"},
      {"Paid from", "Paid to"}
    ]
  end

  @impl true
  @spec filter_form_field_opts(%User{} | nil) :: keyword(keyword())
  def filter_form_field_opts(%User{admin: true}) do
    filter_form_field_opts()
  end

  # The `%User{}` is not an administrator.
  def filter_form_field_opts(_user) do
    filter_form_field_opts()
    |> Keyword.delete_first(:user_email_trimmed)
  end

  # Options for all filter form fields.
  @spec filter_form_field_opts() :: keyword(keyword())
  defp filter_form_field_opts() do
    [
      product_name_trimmed: text_field_opts("Product name"),
      paid_at: select_field_opts("Paid", :not_empty),
      inserted_at: datetime_field_opts("Created from", :>=),
      inserted_at: datetime_field_opts("Created to", :<=),
      total_filterable_trimmed: decimal_field_opts("Total from", :>=, "0.00"),
      total_filterable_trimmed: decimal_field_opts("Total to", :<=),
      paid_at: datetime_field_opts("Paid from", :>=),
      paid_at: datetime_field_opts("Paid to", :<=),
      user_email_trimmed: text_field_opts("User e-mail")
    ]
  end

  @spec custom_field_opts() :: keyword(keyword())
  defp custom_field_opts() do
    [
      product_name_trimmed: custom_product_name_field_opts(),
      total_filterable_trimmed: custom_total_filterable_field_opts(),
      user_email_trimmed: custom_associated_object_field_opts(:user, :email),
    ]
  end

  @spec join_field_opts() :: keyword(keyword())
  defp join_field_opts() do
    [total_filterable: join_field_opts(:total_filterable, :sum, :decimal)]
  end

  @spec custom_product_name_field_opts() :: keyword()
  defp custom_product_name_field_opts() do
    custom_associated_object_field_opts(:product, :name)
  end

  @spec custom_total_filterable_field_opts() :: keyword()
  defp custom_total_filterable_field_opts() do
    custom_decimal_field_opts([source: :total_filterable, field: :sum])
  end
end
