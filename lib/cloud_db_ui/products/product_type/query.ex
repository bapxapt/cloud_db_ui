defmodule CloudDbUi.Products.ProductType.Query do
  import Ecto.Query

  alias CloudDbUi.Products.Product
  alias CloudDbUi.Products.ProductType

  @doc """
  Names the concept of a base query.
  This is the constructor for the `ProductType.Query` module.
  """
  @spec base() :: %Ecto.Query{}
  def base(), do: from(t in ProductType, [as: :type])

  @doc """
  Only assignable product types.
  """
  @spec assignable(%Ecto.Query{}) :: %Ecto.Query{}
  def assignable(query \\ base()) do
    where(query, [type: t], t.assignable == true)
  end

  @doc """
  Preloads `:products`.
  """
  @spec with_preloaded_products(%Ecto.Query{}) :: %Ecto.Query{}
  def with_preloaded_products(query \\ base()) do
    query
    |> join_products()
    |> preload([type: t, product: p], [products: p])
  end

  @doc """
  Replaces `:products` with product count.
  """
  @spec with_product_count(%Ecto.Query{}) :: %Ecto.Query{}
  def with_product_count(query \\ base()) do
    query
    |> join_products()
    |> group_by([type: t], [t.id])
    |> select_merge([type: t, product: p], %{products: count(p)})
  end

  @spec join_products(%Ecto.Query{}) :: %Ecto.Query{}
  defp join_products(query) do
    join(
      query,
      :left,
      [type: t],
      p in Product,
      [on: p.product_type_id == t.id, as: :product]
    )
  end
end
