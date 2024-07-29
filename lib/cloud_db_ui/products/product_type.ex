defmodule CloudDbUi.Products.ProductType do
  use Ecto.Schema

  alias CloudDbUi.Products.Product
  alias Ecto.Changeset

  import Ecto.Changeset
  import CloudDbUiWeb.Utilities
  import CloudDbUi.Changeset

  @type attrs() :: CloudDbUi.Type.attrs()
  @type errors() :: CloudDbUi.Type.errors()

  schema("product_types") do
    field :name, :string
    field :description, :string
    field :assignable, :boolean, default: true
    has_many :products, Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec validation_changeset(%__MODULE__{}, attrs(), boolean()) :: %Changeset{}
  def validation_changeset(type, attrs, validate_unique?) do
    type
    |> cast(attrs, [:assignable])
    |> cast_transformed(attrs, [:name, :description], &trim/1)
    |> validate_required([:name])
    |> validate_lengths(%{name: [max: 60], description: [max: 200]})
    |> maybe_unsafe_validate_unique_constraint(:name, validate_unique?)
    # Reset trimmed changes to their initial values.
    |> put_changes_from_attrs(attrs, [:name, :description])
  end

  @doc false
  @spec saving_changeset(%__MODULE__{}, attrs()) :: %Changeset{}
  def saving_changeset(type, attrs) do
    type
    |> validation_changeset(attrs, true)
    |> update_changes_if_valid([:name, :description], &trim/1)
  end

  @doc """
  A changeset for deletion. Invalid if `:products` is not zero.
  """
  @spec deletion_changeset(%__MODULE__{}) :: %Changeset{}
  def deletion_changeset(%__MODULE__{products: 0} = type), do: change(type)

  def deletion_changeset(%__MODULE__{} = type) do
    type
    |> change()
    |> add_error(:products, "has products", [validation: :products_none])
  end
end
