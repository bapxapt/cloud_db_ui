defmodule CloudDbUi.Products do
  @moduledoc """
  The Products context.
  """

  import Ecto.Query, warn: false

  alias CloudDbUi.Repo
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Products.{Product, ProductType}
  alias Ecto.Changeset

  @type db_id() :: CloudDbUi.Type.db_id()
  @type attrs() :: CloudDbUi.Type.attrs()

  @doc """
  Return the list of products. Preloads `:type`.
  Replaces `:orders` and `:paid_orders` with order count.
  """
  @spec list_products_with_type_and_order_count() :: [%Product{}]
  def list_products_with_type_and_order_count() do
    Product.Query.with_preloaded_type_and_order_count()
    |> Repo.all()
  end

  @doc """
  Return the list of orderable products. Preloads `:type`.
  """
  @spec list_orderable_products_with_type() :: [%Product{}]
  def list_orderable_products_with_type() do
    Product.Query.orderable_with_preloaded_type()
    |> Repo.all()
  end

  @doc """
  Return the list of product types.

  ## Examples

      iex> list_product_types()
      [%ProductType{}, ...]

  """
  def list_product_types, do: Repo.all(ProductType)

  @doc """
  Return the list of product types. Each type has `:products`
  replaced with product count.
  """
  def list_product_types_with_product_count() do
    ProductType.Query.with_product_count()
    |> Repo.all()
  end

  @doc """
  Return the list of product types that can be assigned to products.
  """
  def list_assignable_product_types() do
    ProductType.Query.assignable()
    |> Repo.all()
  end

  @doc """
  Get a single product. No preloads.

  Raises `Ecto.NoResultsError` if the product does not exist.

  ## Examples

      iex> get_product!(123)
      %Product{}

      iex> get_product!(456)
      ** (Ecto.NoResultsError)

  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Get a single product. Preloads `:product_type`.
  """
  @spec get_product_with_type(db_id()) :: %Product{} | nil
  def get_product_with_type(id) do
    Product.Query.with_preloaded_type()
    |> Repo.get(id)
  end

  @doc """
  Get a single product. Preloads `:type`.
  Replaces `:orders` and `:paid_orders` with order count.
  """
  @spec get_product_with_type_and_order_count!(db_id()) ::
          %Product{}
  def get_product_with_type_and_order_count!(id) do
    Product.Query.with_preloaded_type_and_order_count()
    |> Repo.get!(id)
  end

  @doc """
  Get a single product. Replaces `:orders` and `:paid_orders`
  with order count.
  """
  @spec get_product_with_order_count!(db_id()) :: %Product{}
  def get_product_with_order_count!(id) do
    Product.Query.with_order_count()
    |> Repo.get!(id)
  end

  @doc """
  Get a single product. Preloads `:type` and `:orders`.
  Each order has a preloaded `:user`.
  """
  @spec get_product_with_type_and_order_suborder_users!(db_id()) :: %Product{}
  def get_product_with_type_and_order_suborder_users!(id) do
    Product.Query.with_preloaded_type_and_order_suborder_users()
    |> Repo.get!(id)
    |> Map.update!(:orders, &Order.fill_subtotal_and_total/1)
  end

  @doc """
  Get a single orderable product. Preloads `:type`.
  """
  @spec get_orderable_product_with_type!(db_id()) :: %Product{}
  def get_orderable_product_with_type!(id) do
    Product.Query.orderable_with_preloaded_type()
    |> Repo.get!(id)
  end

  @doc """
  Get a single product type. Preloads `:products`.

  Raises `Ecto.NoResultsError` if the product type does not exist.
  """
  def get_product_type_with_products!(id) do
    ProductType.Query.with_preloaded_products()
    |> Repo.get!(id)
  end

  @doc """
  Get a single product type. Replaces `:products` with
  product count.
  """
  def get_product_type_with_product_count!(id) do
    ProductType.Query.with_product_count()
    |> Repo.get!(id)
  end

  @doc """
  Creates a product.

  ## Examples

      iex> create_product(%{field: value})
      {:ok, %Product{}}

      iex> create_product(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_product(attrs(), %ProductType{}, [String.t()]) ::
          {:ok, %Product{}} | {:error, %Changeset{}}
  def create_product(attrs \\ %{}, type, upload_errors \\ []) do
    %Product{}
    |> Product.saving_changeset(attrs, type, upload_errors)
    |> Repo.insert()
  end

  @doc """
  Create a product type.

  ## Examples

      iex> create_product_type(%{field: value})
      {:ok, %ProductType{}}

      iex> create_product_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_product_type(attrs()) ::
          {:ok, %ProductType{}} | {:error, %Changeset{}}
  def create_product_type(attrs \\ %{}) do
    %ProductType{}
    |> ProductType.saving_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a product.

  ## Examples

      iex> update_product(product, %{field: new_value}, type)
      {:ok, %Product{}}

      iex> update_product(product, %{field: bad_value}, type)
      {:error, %Ecto.Changeset{}}

  """
  @spec update_product(%Product{}, attrs(), %ProductType{}, [String.t()]) ::
          {:ok, %Product{}} | {:error, %Changeset{}}
  def update_product(product, attrs, type, uplo_errors \\ []) do
    product
    |> Product.saving_changeset(attrs, type, uplo_errors)
    |> Repo.update()
  end

  @doc """
  Update a product type.

  ## Examples

      iex> update_product_type(type, %{field: new_value})
      {:ok, %ProductType{}}

      iex> update_product_type(type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_product_type(%ProductType{}, attrs()) ::
          {:ok, %ProductType{}} | {:error, %Changeset{}}
  def update_product_type(%ProductType{} = type, attrs) do
    type
    |> ProductType.saving_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a product.

  ## Examples

      iex> delete_product(product)
      {:ok, %Product{}}

      iex> delete_product(product)
      {:error, %Ecto.Changeset{}}

  """
  def delete_product(%Product{} = product) do
    product
    |> Product.deletion_changeset()
    |> Repo.delete()
  end

  @doc """
  Delete a product type.

  ## Examples

      iex> delete_product_type(type)
      {:ok, %ProductType{}}

      iex> delete_product_type(type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_product_type(%ProductType{} = type) do
    type
    |> ProductType.deletion_changeset()
    |> Repo.delete()
  end

  @doc """
  Return an `%Ecto.Changeset{}` for tracking product changes.

  ## Examples

      iex> change_product(product)
      %Ecto.Changeset{data: %Product{}}

  """
  @spec change_product(
          %Product{},
          attrs(),
          %ProductType{} | nil,
          [String.t()]
        ) :: %Changeset{}
  def change_product(product, attrs \\ %{}, type \\ nil, uplo_errors \\ []) do
    Product.validation_changeset(product, attrs, type, uplo_errors)
  end

  @doc """
  Return an `%Ecto.Changeset{}` for tracking product type changes.

  ## Examples

      iex> change_product_type(type)
      %Ecto.Changeset{data: %ProductType{}}

  """
  @spec change_product_type(%ProductType{}, attrs(), boolean()) :: %Changeset{}
  def change_product_type(
        %ProductType{} = type,
        attrs \\ %{},
        validate_unique? \\ true
      ) do
    ProductType.validation_changeset(type, attrs, validate_unique?)
  end
end