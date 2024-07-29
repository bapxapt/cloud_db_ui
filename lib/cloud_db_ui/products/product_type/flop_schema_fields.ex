defmodule CloudDbUi.Products.ProductType.FlopSchemaFields do
  use CloudDbUi.FlopSchemaFields

  @impl true
  @spec filterable_fields() :: [atom()]
  def filterable_fields() do
    [
      :name_trimmed,
      :description_trimmed,
      :inserted_at,
      :assignable,
      :has_products
    ]
  end

  @impl true
  @spec sortable_fields() :: [atom()]
  def sortable_fields() do
    [:id, :name, :description, :inserted_at, :assignable]
  end

  @impl true
  @spec adapter_opts() :: keyword([atom() | keyword(keyword())])
  def adapter_opts(), do: [custom_fields: custom_field_opts()]

  @impl true
  @spec list_objects(%Flop{}, %User{} | nil) ::
          {:ok, {[struct()], %Flop.Meta{}}} | {:error, %Flop.Meta{}}
  def list_objects(%Flop{} = flop, _user) do
    CloudDbUi.Products.list_product_types_with_product_count(flop)
  end

  @impl true
  @spec delete_object_by_id(%Socket{}, String.t()) :: %Socket{}
  def delete_object_by_id(socket, id) do
    CloudDbUiWeb.ProductTypeLive.Actions.delete_product_type(
      socket,
      CloudDbUi.Products.get_product_type_with_product_count!(id)
    )
  end

  @impl true
  @spec min_max_field_labels() :: [{String.t(), String.t()}]
  def min_max_field_labels(), do: [{"Created from", "Created to"}]

  @impl true
  @spec filter_form_field_opts(%User{} | nil) :: keyword(keyword())
  def filter_form_field_opts(_user) do
    [
      name_trimmed: text_field_opts("Name", :ilike),
      description_trimmed: text_field_opts("Description", :ilike),
      inserted_at: datetime_field_opts("Created from", :>=),
      inserted_at: datetime_field_opts("Created to", :<=),
      assignable: select_field_opts("Assignable"),
      has_products: select_field_opts("Has products", :!=)
    ]
  end

  @spec custom_field_opts() :: keyword(keyword())
  defp custom_field_opts() do
    [
      name_trimmed: custom_text_field_opts(:name),
      description_trimmed: custom_text_field_opts(:description),
      has_products: custom_has_objects_field_opts(:product)
    ]
  end
end
