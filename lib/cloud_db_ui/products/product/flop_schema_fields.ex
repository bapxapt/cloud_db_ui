defmodule CloudDbUi.Products.Product.FlopSchemaFields do
  use CloudDbUi.FlopSchemaFields

  @impl true
  @spec filterable_fields() :: [atom()]
  def filterable_fields() do
    [
      :id,
      :product_type_name,
      :name_trimmed,
      :description_trimmed,
      :unit_price_trimmed,
      :inserted_at,
      :orderable,
      :has_paid_orders
    ]
  end

  @impl true
  @spec sortable_fields() :: [atom()]
  def sortable_fields() do
    [
      :id,
      :product_type_id,
      :name,
      :description,
      :unit_price,
      :inserted_at,
      :orderable
    ]
  end

  @impl true
  @spec adapter_opts() :: keyword([atom() | keyword(keyword())])
  def adapter_opts(), do: [custom_fields: custom_field_opts()]

  # The `%User{}` is an administrator, can see any products.
  @impl true
  @spec list_objects(%Flop{}, %User{} | nil) ::
          {:ok, {[struct()], %Flop.Meta{}}} | {:error, %Flop.Meta{}}
  def list_objects(%Flop{} = flop, %User{admin: true}) do
    CloudDbUi.Products.list_products_with_type_and_order_count(flop)
  end

  # The `%User{}` is not an administrator, can see only orderable products.
  def list_objects(%Flop{} = flop, _user) do
    CloudDbUi.Products.list_orderable_products_with_type(flop)
  end

  @impl true
  @spec delete_object_by_id(%Socket{}, String.t()) :: %Socket{}
  def delete_object_by_id(socket, id) do
    CloudDbUiWeb.ProductLive.Actions.delete_product(
      socket,
      CloudDbUi.Products.get_product_with_order_count!(id)
    )
  end

  @impl true
  @spec min_max_field_labels() :: [{String.t(), String.t()}]
  def min_max_field_labels() do
    [{"Created from", "Created to"}, {"Price from", "Price to"}]
  end

  @impl true
  @spec filter_form_field_opts(%User{} | nil) :: keyword(keyword())
  def filter_form_field_opts(%User{admin: true}) do
    [
      name_trimmed: text_field_opts("Name"),
      description_trimmed: text_field_opts("Description"),
      inserted_at: datetime_field_opts("Created from", :>=),
      inserted_at: datetime_field_opts("Created to", :<=),
      unit_price_trimmed: unit_price_field_opts(:>=),
      unit_price_trimmed: unit_price_field_opts(:<=),
      product_type_name: text_field_opts("Product type"),
      orderable: select_field_opts("Orderable"),
      has_paid_orders: select_field_opts("Has paid orders", :!=)
    ]
  end

  # The `%User{}` is not an administrator.
  def filter_form_field_opts(_user) do
    [
      name_trimmed: text_field_opts("Name"),
      description_trimmed: text_field_opts("Description"),
      unit_price_trimmed: unit_price_field_opts(:>=),
      unit_price_trimmed: unit_price_field_opts(:<=),
      product_type_name: text_field_opts("Product type")
    ]
  end

  @spec custom_field_opts() :: keyword(keyword())
  defp custom_field_opts() do
    [
      product_type_name: custom_product_type_name_field_opts(),
      name_trimmed: custom_text_field_opts(:name),
      description_trimmed: custom_text_field_opts(:description),
      unit_price_trimmed: custom_decimal_field_opts(:unit_price),
      has_paid_orders: custom_has_objects_field_opts(:order, :paid_at)
    ]
  end

  @spec custom_product_type_name_field_opts() :: keyword()
  defp custom_product_type_name_field_opts() do
    custom_associated_object_field_opts(:product_type, :name)
  end

  @spec unit_price_field_opts(atom()) :: keyword()
  defp unit_price_field_opts(:>=) do
    decimal_field_opts("Price from", :>=, "0.00")
  end

  defp unit_price_field_opts(:<=) do
    decimal_field_opts("Price to", :<=, User.balance_limit())
  end
end
