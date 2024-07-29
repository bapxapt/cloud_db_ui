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

  schema "products" do
    field :name, :string
    field :description, :string
    field :unit_price, :decimal
    field :orderable, :boolean, default: true
    field :image_path, :string
    # Instead of `field :product_type_id, :id`.
    belongs_to :product_type, ProductType
    has_many :suborders, SubOrder
    has_many :orders, through: [:suborders, :order]

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec validation_changeset(%__MODULE__{}, attrs(), [String.t()]) ::
          %Changeset{}
  def validation_changeset(product, attrs, upload_errors) do
    product
    |> cast(attrs, [:product_type_id, :orderable, :image_path])
    |> cast_transformed(attrs, [:unit_price, :name, :description], &trim/1)
    |> validate_required([:product_type_id, :name, :unit_price])
    |> validate_number(:product_type_id, [greater_than_or_equal_to: 1])
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
  @spec saving_changeset(%__MODULE__{}, attrs(), [String.t()]) :: %Changeset{}
  def saving_changeset(product, attrs, upload_errors) do
    product
    |> validation_changeset(attrs, upload_errors)
    |> update_changes_if_valid([:name, :description], &trim/1)
    |> cast_transformed_if_valid(attrs, [:unit_price], &trim/1)
  end

  @spec add_upload_errors(%Changeset{}, atom(), [String.t()]) :: %Changeset{}
  defp add_upload_errors(%Changeset{} = changeset, key, upload_errors) do
    Enum.reduce(upload_errors, changeset, fn error, acc ->
      add_error(acc, key, error, [validation: :upload_error])
    end)
  end
end
