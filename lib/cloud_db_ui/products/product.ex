defmodule CloudDbUi.Products.Product do
  use Ecto.Schema

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUi.Products.ProductType
  alias Ecto.Changeset

  import Ecto.Changeset
  import CloudDbUi.Changeset
  import CloudDbUiWeb.Utilities

  @type attrs() :: CloudDbUi.Type.attrs()

  schema("products") do
    field :name, :string
    field :description, :string
    field :unit_price, :decimal, default: Decimal.new("0.00")
    field :orderable, :boolean, default: true
    field :image_path, :string
    field :paid_orders, :integer, virtual: true, default: 0
    # Instead of `field :product_type_id, :id`.
    belongs_to :product_type, ProductType
    has_many :suborders, SubOrder
    has_many :orders, through: [:suborders, :order]

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec validation_changeset(%__MODULE__{},
          attrs(),
          %ProductType{} | nil,
          [String.t()]
        ) :: %Changeset{}
  def validation_changeset(%__MODULE__{} = prod, attrs, type, upload_errors) do
    prod
    |> cast(attrs, [:product_type_id, :orderable, :image_path])
    |> cast_transformed(attrs, [:unit_price, :name, :description], &trim/1)
    |> validate_required([:product_type_id, :name])
    |> validate_required_with_default(attrs, [:unit_price])
    |> maybe_validate_product_type_id(type)
    |> maybe_validate_format_decimal(attrs, :unit_price)
    |> maybe_validate_format_not_negative_zero(attrs, :unit_price)
    |> validate_sign(:unit_price, [sign: :non_negative])
    |> validate_number(
      :unit_price,
      [less_than_or_equal_to: User.balance_limit()]
    )
    |> validate_lengths(%{name: [max: 60], description: [max: 200]})
    |> add_upload_errors(:image_path, upload_errors)
    # Reset trimmed changes to their initial values.
    |> put_changes_from_attrs(attrs, [:unit_price, :name, :description])
  end

  @doc false
  @spec saving_changeset(
          %__MODULE__{},
          attrs(),
          %ProductType{} | nil,
          [String.t()]
        ) :: %Changeset{}
  def saving_changeset(%__MODULE__{} = product, attrs, type, upload_errors) do
    product
    |> validation_changeset(attrs, type, upload_errors)
    |> update_changes_if_valid([:name, :description], &trim/1)
    |> cast_transformed_if_valid(attrs, [:unit_price], &trim/1)
    |> update_changes_if_valid([:unit_price], &Decimal.round(&1, 2))
  end

  @doc """
  A changeset for deletion. Invalid if `:paid_orders` is not zero.
  """
  @spec deletion_changeset(%__MODULE__{}) :: %Changeset{}
  def deletion_changeset(%__MODULE__{paid_orders: 0} = type), do: change(type)

  def deletion_changeset(%__MODULE__{} = type) do
    type
    |> change()
    |> add_error(
      :paid_orders,
      "has paid orders of it",
      [validation: :paid_orders_none]
    )
  end

  @spec maybe_validate_product_type_id(%Changeset{}, %ProductType{} | nil) ::
          %Changeset{}
  defp maybe_validate_product_type_id(
         %{changes: %{product_type_id: id}} = set,
         type
       ) do
    cond do
      !type ->
        add_product_type_id_error(
          set,
          "product type not found",
          :product_type_id_found
        )

      id != type.id ->
        add_product_type_id_error(
          set,
          "product type ID does not match",
          :product_type_id_matches
        )

      !type.assignable ->
        add_product_type_id_error(
          set,
          "the product type is not assignable",
          :product_type_id_assignable
        )

      true ->
        set
    end
  end

  # `changeset.changes` do not contain `:product_type_id`.
  defp maybe_validate_product_type_id(changeset, _type), do: changeset

  @spec add_product_type_id_error(%Changeset{}, String.t(), atom()) ::
          %Changeset{}
  defp add_product_type_id_error(%Changeset{} = set, message, validation) do
    add_error(set, :product_type_id, message, [validation: validation])
  end

  @spec add_upload_errors(%Changeset{}, atom(), [String.t()]) :: %Changeset{}
  defp add_upload_errors(%Changeset{} = changeset, key, upload_errors) do
    Enum.reduce(upload_errors, changeset, fn error, acc ->
      add_error(acc, key, error, [validation: :upload_error])
    end)
  end
end