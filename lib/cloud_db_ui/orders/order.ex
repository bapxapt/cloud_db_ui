defmodule CloudDbUi.Orders.Order do
  use Ecto.Schema

  import CloudDbUi.Orders.Order.FlopSchemaFields
  import CloudDbUiWeb.Utilities
  import CloudDbUi.Changeset
  import Ecto.Changeset

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias Ecto.Changeset

  @type attrs :: CloudDbUi.Type.attrs()

  @derive {
    Flop.Schema,
    filterable: filterable_fields(),
    sortable: sortable_fields(),
    adapter_opts: adapter_opts(),

    # TODO: default_limit: 25,

    default_limit: 6,
    max_limit: 100,
    default_order: %{order_by: [:paid_at], order_directions: [:desc]}
  }

  schema("orders") do
    field :total, :decimal, virtual: true, default: nil
    field :paid_at, :utc_datetime_usec, default: nil
    field :paid, :boolean, virtual: true, default: false
    # Instead of `field :user_id, :id`.
    belongs_to :user, User
    has_many :suborders, SubOrder, [preload_order: [desc: :id]]

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for validation when creating or editing an order
  as an admin.
  """
  @spec validation_changeset(%Order{}, attrs(), %User{} | nil) :: %Changeset{}
  def validation_changeset(%Order{} = order, attrs, user) do
    order
    |> cast(attrs, [:paid, :paid_at])
    # Skipping `cast()`: a required `"user_id"` is expected to be
    # an integer, but is a string.
    |> maybe_put_user_id(order)
    |> validate_required([:user_id])
    |> maybe_validate_user_id(user)
    |> maybe_validate_required_paid_at()
    |> validate_change(:paid_at, &validator_not_in_the_far_past/2)
    |> validate_change(:paid_at, &validator_not_in_the_future/2)
  end

  @doc """
  A changeset for ordering a product as a user with no unpaid orders,
  or for saving when creating/editing an order as an admin.
  `validation_changeset()` with extra steps.
  """
  @spec saving_changeset(%Order{}, attrs(), %User{} | nil) :: %Changeset{}
  def saving_changeset(%Order{} = order, attrs, user) do
    order
    |> validation_changeset(attrs, user)
    |> maybe_replace_and_validate_user_id(user)
    |> maybe_clear_paid_at()
  end

  @doc """
  A changeset for paying for an order as a user.
  """
  @spec payment_changeset(%Order{}) :: %Changeset{}
  def payment_changeset(%Order{paid_at: nil} = order) do
    change(order, %{paid: true, paid_at: DateTime.utc_now()})
  end

  def payment_changeset(%Order{} = order) do
    changeset_with_already_paid_error(order)
  end

  @doc """
  A changeset for deletion. Invalid if the `order` has been paid for.
  """
  @spec deletion_changeset(%Order{}) :: %Changeset{}
  def deletion_changeset(%Order{paid_at: nil} = order), do: change(order)

  def deletion_changeset(%Order{} = order) do
    changeset_with_already_paid_error(order)
  end

  @doc """
  Fill the `:subtotal` virtual field in each sub-order of an `order`,
  then fill the `:total` field, unless it is not `nil`.
  """
  @spec maybe_fill_subtotal_and_total(%Order{}) :: %Order{}
  def maybe_fill_subtotal_and_total(%Order{} = order) do
    order
    |> Map.replace(
      :suborders,
      Enum.map(order.suborders, &SubOrder.maybe_fill_subtotal/1)
    )
    |> maybe_fill_total()
  end

  @doc """
  Get a preloaded suborder by a string ID or by a `%Product{}`.

  If getting by a `%Product{}`, both `:product_id` and `:unit_price`
  must match.
  """
  @spec get_suborder(%Order{}, %Product{}) :: %SubOrder{} | nil
  def get_suborder(order, %Product{} = prod) when is_list(order.suborders) do
    Enum.find(
      order.suborders,
      &(&1.product_id == prod.id and &1.unit_price == prod.unit_price)
    )
  end

  @spec get_suborder(%Order{}, String.t()) :: %SubOrder{} | nil
  def get_suborder(order, suborder_id) when is_list(order.suborders) do
    Enum.find(order.suborders, &("#{&1.id}" == suborder_id))
  end

  @doc """
  Fetch one field of `:product` in all `:suborders` of the same `order`.

  This requires the `order` to have preloaded `:suborders`,
  and each of these sub-orders to have a preloaded `:product`.
  """
  @spec product_field_values!(%Order{}, atom()) :: [any()]
  def product_field_values!(%Order{} = order, product_field) do
    Enum.map(order.suborders, &Map.fetch!(&1.product, product_field))
  end

  @doc """
  Determine whether an order is deletable. A user can delete
  only own unpaid orders. An admin can delete any unpaid orders.
  """
  @spec deletable?(%Order{}, %User{}) :: boolean()
  def deletable?(%Order{} = order, %User{} = user) do
    !order.paid and (user.admin or user.id == order.user_id)
  end

  @doc """
  Fetch the `:quantity` error message from `changeset.errors`.
  """
  def quantity_error!(%Changeset{valid?: false} = changeset) do
    changeset.errors
    |> Keyword.fetch!(:quantity)
    |> elem(0)
    |> String.capitalize()
    |> Kernel.<>(".")
  end

  # For `deletion_changeset()` and for `payment_changeset()`.
  @spec changeset_with_already_paid_error(%Order{}, String.t()) :: %Changeset{}
  defp changeset_with_already_paid_error(
         %Order{} = order,
         msg \\ "the order has been paid for"
       ) do
    order
    |> change()
    |> add_error(:paid, msg, [validation: :paid_unpaid])
  end

  # Put a change of `:user_id`, if `"user_id"` exists in change`set.params`,
  # and this user ID is differing from the `:user_id` in `order`.
  @spec maybe_put_user_id(%Changeset{}, %Order{}) :: %Changeset{}
  defp maybe_put_user_id(%Changeset{} = set, %Order{user_id: id}) do
    (set.params["user_id"] != nil and "#{id}" != "#{set.params["user_id"]}")
    |> case do
      true -> put_change(set, :user_id, "#{set.params["user_id"]}")
      false -> set
    end
  end

  @spec maybe_validate_user_id(%Changeset{}, %User{} | nil) :: %Changeset{}
  defp maybe_validate_user_id(%{changes: %{user_id: id_mail}} = set, user) do
    trimmed = String.trim(id_mail)

    cond do
      trimmed == "" ->
        add_user_id_error(set, "can't be blank", :required)

      String.length(trimmed) > 160 ->
        add_user_id_error(set, "should be at most 160 character(s)", :length)

      !valid_id?(trimmed) and !User.valid_email?(trimmed) ->
        add_user_id_error(
          set,
          "neither an ID nor a valid e-mail",
          :user_id_bad
        )

      !user ->
        add_user_id_error(set, "user not found", :user_id_found)

      id_mail != "#{user.id}" and trim_downcase(id_mail) != user.email ->
        add_user_id_error(
          set,
          "both user ID and user e-mail do not match",
          :user_id_matches
        )

      user.admin ->
        add_user_id_error(
          set,
          "cannot assign an order to an administrator",
          :user_id_not_admin
        )

      true ->
        set
    end
  end

  # `changeset.changes` do not contain `:user_id`.
  defp maybe_validate_user_id(changeset, _user), do: changeset

  @spec add_user_id_error(%Changeset{}, String.t(), atom()) :: %Changeset{}
  defp add_user_id_error(%Changeset{} = changeset, message, validation) do
    add_error(changeset, :user_id, message, [validation: validation])
  end

  # Require `:paid_at` when the "Paid" check box is checked.
  @spec maybe_validate_required_paid_at(%Changeset{}) :: %Changeset{}
  defp maybe_validate_required_paid_at(%Changeset{} = changeset) do
    maybe_validate_required_paid_at(changeset, "#{changeset.params["paid"]}")
  end

  @spec maybe_validate_required_paid_at(%Changeset{}, String.t()) ::
          %Changeset{}
  defp maybe_validate_required_paid_at(%Changeset{} = changeset, "true") do
    validate_required(
      changeset,
      [:paid_at],
      [message: "can't be blank in a paid order"]
    )
  end

  defp maybe_validate_required_paid_at(%Changeset{} = set, _paid), do: set

  # Replace any potential e-mail address stored under `:user_id` with
  # an actual integer ID of the `user`.
  @spec maybe_replace_and_validate_user_id(%Changeset{}, %User{}) ::
          %Changeset{}
  defp maybe_replace_and_validate_user_id(
         %{changes: %{user_id: _}, errors: []} = changeset,
         user
       ) do
    changeset
    |> put_change(:user_id, user.id)
    |> validate_number(:user_id, [greater_than_or_equal_to: 1])
  end

  # No `:user_id` in `changeset.changes`, or `changeset.errors != []`.
  defp maybe_replace_and_validate_user_id(changeset, _user), do: changeset

  @spec maybe_clear_paid_at(%Changeset{}) :: %Changeset{}
  defp maybe_clear_paid_at(%{valid?: false} = changeset), do: changeset

  # The `changeset` has no errors.
  defp maybe_clear_paid_at(changeset) do
    maybe_clear_paid_at(changeset, "#{changeset.params["paid"]}")
  end

  # The "Paid" check box has been unchecked.
  @spec maybe_clear_paid_at(%Changeset{}, String.t()) :: %Changeset{}
  defp maybe_clear_paid_at(set, "false"), do: put_change(set, :paid_at, nil)

  # `changeset.params` do not contain `"paid"` (no "Paid" check box),
  # or the "Paid" check box is checked (`"true"`). Do not clear `:paid_at`.
  defp maybe_clear_paid_at(changeset, _paid?), do: changeset

  # Expects each sub-order in the list under `:suborders` to have filled
  # `:subtotal`.
  @spec maybe_fill_total(%Order{}) :: %Order{}
  defp maybe_fill_total(%Order{total: nil} = order) do
    total =
      Enum.reduce(order.suborders, Decimal.new("0.00"), fn suborder, acc ->
        acc
        |> Decimal.add(suborder.subtotal)
        |> Decimal.round(2)
      end)

    Map.replace(order, :total, total)
  end

  # `:total` is not `nil`.
  defp maybe_fill_total(%Order{} = order), do: order
end
