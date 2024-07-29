defmodule CloudDbUi.Products.ProductType.Query do
  import CloudDbUi.Query
  import Ecto.Query

  @doc """
  Names the concept of a base query. The constructor for this module.
  """
  @spec base() :: %Ecto.Query{}
  def base() do
    from(t in CloudDbUi.Products.ProductType, [as: :product_type])
  end

  @doc """
  Only assignable product types.
  """
  @spec assignable(%Ecto.Query{}) :: %Ecto.Query{}
  def assignable(query \\ base()) do
    where(query, [product_type: t], t.assignable == true)
  end

  @doc """
  Preloads `:products`.
  """
  @spec with_preloaded_products(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_products(query \\ base()) do
    query
    |> join_products()
    |> preload([product_type: t, product: p], [products: p])
  end

  @doc """
  Replaces `:products` with product count.
  """
  @spec with_product_count(%Ecto.Query{}) :: %Ecto.Query{}
  def with_product_count(query \\ base()) do
    query
    |> join_products()
    |> group_by([product_type: t], [t.id])
    |> select_merge([product: p], %{products: count(p)})
  end

  @spec join_products(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_products(query) do
    join_many(query, :product_type, :products, :product)
  end
end
