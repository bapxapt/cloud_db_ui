defmodule CloudDbUi.Orders.SubOrder do
  use Ecto.Schema

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.Order
  alias Ecto.Changeset

  import Ecto.Changeset
  import CloudDbUi.Changeset
  import CloudDbUiWeb.Utilities

  @type attrs() :: CloudDbUi.Type.attrs()

  @quantity_limit 100_000

  schema("suborders") do
    # A snapshot of the `:unit_price` of the product.
    field :unit_price, :decimal, default: Decimal.new("0.00")
    field :quantity, :integer
    field :subtotal, :decimal, virtual: true, default: nil
    # Instead of `field :product_id, :id`.
    belongs_to :product, Product
    # Instead of `field :order_id, :id`.
    belongs_to :order, Order

    timestamps([type: :utc_datetime])
  end

  @doc """
  A changeset for validation when creating or editing a sub-order
  as an admin.
  """
  @spec validation_changeset(
          %__MODULE__{},
          attrs(),
          %Order{} | nil,
          %Product{} | nil
        ) :: %Changeset{}
  def validation_changeset(%__MODULE__{} = suborder, attrs, order, product) do
    suborder
    |> cast(attrs, [:order_id, :product_id, :quantity])
    |> cast_transformed(attrs, [:unit_price], &trim/1)
    |> validate_required([:order_id, :product_id, :quantity])
    |> validate_required_with_default([:unit_price])
    |> maybe_validate_order_id(order)
    |> maybe_validate_product_id(product)
    |> validate_number_quantity()
    |> maybe_validate_format_decimal(:unit_price)
    |> maybe_validate_format_not_negative_zero(:unit_price)
    |> validate_number_unit_price()
    |> maybe_put_subtotal(suborder, [:quantity, :unit_price])
    # Reset `:unit_price` to its initial untrimmed value.
    |> put_changes_from_attrs(attrs, [:unit_price])
  end

  @doc """
  A changeset for saving when creating or editing a sub-order
  as an admin. `validation_changeset()` with extra steps.
  """
  @spec saving_changeset(
          %__MODULE__{},
          attrs(),
          %Order{} | nil,
          %Product{} | nil
        ) :: %Changeset{}
  def saving_changeset(%__MODULE__{} = suborder, attrs, order, product) do
    suborder
    |> validation_changeset(attrs, order, product)
    |> case do
      %{valid?: true} = valid_set ->
        valid_set
        |> cast_transformed(attrs, [:unit_price], &trim/1)
        |> update_changes([:unit_price], &Decimal.round(&1, 2))

      %{valid?: false} = invalid_set ->
        invalid_set
    end
  end

  @doc """
  A changeset for editing as a user.
  """
  @spec quantity_changeset(%__MODULE__{}, attrs()) :: %Changeset{}
  def quantity_changeset(%__MODULE__{} = suborder, attrs) do
    suborder
    |> cast(attrs, [:quantity])
    |> validate_required([:quantity])
    |> maybe_validate_quantity_increase(suborder)
    |> validate_number_quantity()
    |> maybe_put_subtotal(suborder, [:quantity])
  end

  @doc """
  A changeset for deletion. Invalid if the `order` has been paid for.
  """
  @spec deletion_changeset(%__MODULE__{}, %Order{}) :: %Changeset{}
  def deletion_changeset(%__MODULE__{} = suborder, order) do
    suborder
    |> change()
    |> force_change(:order_id, order.id)
    |> maybe_validate_order_id(order)
  end

  @doc """
  Fill the `:subtotal` virtual field if it is `nil`.
  """
  @spec maybe_fill_subtotal(%__MODULE__{}) :: %__MODULE__{}
  def maybe_fill_subtotal(%__MODULE__{subtotal: nil} = suborder) do
    Map.replace(suborder, :subtotal, subtotal(suborder))
  end

  def maybe_fill_subtotal(%__MODULE__{} = suborder), do: suborder

  @doc """
  A getter for accessing `@quantity_limit` outside of the module.
  """
  def quantity_limit(), do: @quantity_limit

  # If the current `:unit_price` of a `%Product{}` exceeds the price
  # stored as a snap-shot in the `%SubOrder`, forbid increasing quantity.
  @spec maybe_validate_quantity_increase(%Ecto.Changeset{}, %__MODULE__{}) ::
          %Ecto.Changeset{}
  defp maybe_validate_quantity_increase(
         %{changes: %{quantity: quantity_new}} = set,
         %{product: %Product{} = product} = suborder
       ) do
    if quantity_new > suborder.quantity and unit_price_increased?(suborder) do
      add_error(set, :quantity, quantity_error_message(product))
    else
      set
    end
  end

  # No change of `:quantity`.
  defp maybe_validate_quantity_increase(set, _suborder), do: set

  # Determine whether the snapshot of `:unit_price` in a sub-order is below
  # the current `:unit_price` of the product.
  @spec unit_price_increased?(%__MODULE__{}) :: boolean()
  defp unit_price_increased?(%{product: %Product{} = product} = suborder) do
    suborder.unit_price < product.unit_price
  end

  @spec quantity_error_message(%Product{}) :: String.t()
  defp quantity_error_message(product) do
    Kernel.<>(
      "the current price of the product is PLN #{product.unit_price}, ",
      "cannot increase quantity"
    )
  end

  # If there is a changeset error for any field in `fields`,
  # do not attempt to put a change of `:subtotal`.
  @spec maybe_put_subtotal(%Ecto.Changeset{}, %__MODULE__{}, [atom()]) ::
          %Ecto.Changeset{}
  defp maybe_put_subtotal(%Ecto.Changeset{} = set, suborder, fields) do
    case get_errors(set, fields) == %{} do
      true -> maybe_put_subtotal(set, suborder)
      false -> set
    end
  end

  @spec maybe_put_subtotal(%Ecto.Changeset{}, %__MODULE__{}) ::
          %Ecto.Changeset{}
  defp maybe_put_subtotal(%{changes: c} = changeset, _suborder)
       when not is_map_key(c, :unit_price) and not is_map_key(c, :quantity) do
    changeset
  end

  # A `:quantity` change, a `:unit_price` change (or both)
  # in change`set.changes`.
  defp maybe_put_subtotal(
         %{changes: changes} = changeset,
         %{quantity: qty, unit_price: price} = _suborder
       ) do
    put_change(
      changeset,
      :subtotal,
      subtotal(changes[:unit_price] || price, changes[:quantity] || qty)
    )
  end

  # Return the value of `:subtotal` rounded to two digits after
  # the floating point.
  @spec subtotal(%__MODULE__{}) :: %Decimal{}
  defp subtotal(%__MODULE__{} = suborder) do
    subtotal(suborder.unit_price, suborder.quantity)
  end

  @spec subtotal(%Decimal{} | nil, non_neg_integer() | nil) :: %Decimal{}
  defp subtotal(unit_price, quantity) do
    (unit_price || Decimal.new("0.00"))
    |> Decimal.mult(quantity || 0)
    |> Decimal.round(2)
  end

  @spec validate_number_quantity(%Ecto.Changeset{}) :: %Ecto.Changeset{}
  defp validate_number_quantity(changeset) do
    changeset
    |> validate_number(
      :quantity,
      greater_than_or_equal_to: 1,
      message: "cannot order fewer than one piece"
    )
    |> validate_number(
      :quantity,
      less_than_or_equal_to: @quantity_limit,
      message: "cannot order more than #{@quantity_limit} pieces"
    )
  end

  @spec validate_number_unit_price(%Ecto.Changeset{}) :: %Ecto.Changeset{}
  defp validate_number_unit_price(changeset) do
    changeset
    |> validate_sign(:unit_price, [sign: :non_negative])
    |> validate_number(
      :unit_price,
      [less_than_or_equal_to: User.balance_limit()]
    )
  end

  @spec maybe_validate_order_id(%Changeset{}, %Order{} | nil) :: %Changeset{}
  defp maybe_validate_order_id(%{changes: %{order_id: id}} = set, order) do
    cond do
      !order ->
        add_order_id_error(set, "order not found", :order_id_found)

      id != order.id ->
        add_order_id_error(set, "order ID does not match", :order_id_matches)

      order.paid_at ->
        add_order_id_error(
          set,
          "the order has been paid for",
          :order_id_unpaid
        )

      true ->
        set
    end
  end

  # `changeset.changes` do not contain `:order_id`.
  defp maybe_validate_order_id(changeset, _order), do: changeset

  @spec maybe_validate_product_id(%Changeset{}, %Product{} | nil) ::
          %Changeset{}
  defp maybe_validate_product_id(%{changes: %{product_id: id}} = set, prod) do
    cond do
      !prod ->
        add_product_id_error(set, "product not found", :product_id_found)

      id != prod.id ->
        add_product_id_error(
          set,
          "product ID does not match",
          :product_id_matches
        )

      !prod.orderable ->
        add_product_id_error(
          set,
          "cannot assign a non-orderable product",
          :product_id_orderable
        )

      true ->
        set
    end
  end

  # `changeset.changes` do not contain `:product_id`.
  defp maybe_validate_product_id(changeset, _product), do: changeset

  @spec add_order_id_error(%Changeset{}, String.t(), atom()) :: %Changeset{}
  defp add_order_id_error(%Changeset{} = changeset, message, validation) do
    add_error(changeset, :order_id, message, [validation: validation])
  end

  @spec add_product_id_error(%Changeset{}, String.t(), atom()) :: %Changeset{}
  defp add_product_id_error(%Changeset{} = changeset, message, validation) do
    add_error(changeset, :product_id, message, [validation: validation])
  end
end
