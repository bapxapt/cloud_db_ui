defmodule CloudDbUi.Orders.Order do
  use Ecto.Schema

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.Product
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias Ecto.Changeset

  import Ecto.Changeset
  import CloudDbUiWeb.Utilities
  import CloudDbUi.Changeset

  @type attrs :: CloudDbUi.Type.attrs()

  schema("orders") do
    field :total, :decimal, virtual: true, default: Decimal.new("0.00")
    field :paid_at, :utc_datetime_usec, default: nil
    field :paid, :boolean, virtual: true, default: false
    # Instead of `field :user_id, :id`.
    belongs_to :user, User
    has_many :suborders, SubOrder

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for validation when creating or editing an order
  as an admin.
  """
  @spec validation_changeset(%__MODULE__{}, attrs(), %User{} | nil) ::
          %Changeset{}
  def validation_changeset(%__MODULE__{} = order, attrs, user) do
    order
    |> cast(attrs, [:paid, :paid_at])
    # Skipping `cast()`: a required `"user_id"` or `:user_id`
    # is expected to be an integer, but is a string.
    |> maybe_put_user_id(order, attrs)
    |> validate_required([:user_id])
    |> maybe_validate_user_id(user)
    |> maybe_validate_required([:paid_at], attrs)
    |> validate_change(:paid_at, &validator_not_in_the_far_past/2)
    |> validate_change(:paid_at, &validator_not_in_the_future/2)
  end

  @doc """
  A changeset for ordering a product as a user with no unpaid orders,
  or for saving when creating/editing an order as an admin.
  `validation_changeset()` with extra steps.
  """
  @spec saving_changeset(%__MODULE__{}, attrs(), %User{} | nil) ::
          %Changeset{}
  def saving_changeset(%__MODULE__{} = order, attrs, user) do
    order
    |> validation_changeset(attrs, user)
    |> maybe_replace_and_validate_user_id(user)
    |> maybe_clear_paid_at(attrs)
  end

  @doc """
  A changeset for paying for an order as a user.
  """
  @spec payment_changeset(%__MODULE__{}, attrs()) :: %Changeset{}
  def payment_changeset(%__MODULE__{paid_at: nil} = order, attrs) do
    order
    |> cast(attrs, [:paid])
    |> validate_required([:paid])
    |> validate_acceptance(:paid)
    |> put_change(:paid_at, DateTime.utc_now())
  end

  def payment_changeset(%__MODULE__{} = order, _attrs) do
    changeset_with_already_paid_error(order)
  end

  @doc """
  A changeset for deletion. Invalid if the `order` has been paid for.
  """
  @spec deletion_changeset(%__MODULE__{}) :: %Changeset{}
  def deletion_changeset(%__MODULE__{paid_at: nil} = order), do: change(order)

  def deletion_changeset(%__MODULE__{} = order) do
    changeset_with_already_paid_error(order)
  end

  @doc """
  Fill the :subtotal virtual field in each sub-order of an order,
  then fill the `:total` virtual field of an order.
  """
  @spec fill_subtotal_and_total([%Order{}]) :: [%Order{}]
  def fill_subtotal_and_total(orders) when is_list(orders) do
    Enum.map(orders, &fill_subtotal_and_total/1)
  end

  @spec fill_subtotal_and_total(%Order{}) :: %Order{}
  def fill_subtotal_and_total(%Order{} = order) do
    order
    |> Map.replace(
      :suborders,
      Enum.map(order.suborders, &SubOrder.fill_subtotal/1)
    )
    |> fill_total()
  end

  @doc """
  Get a preloaded suborder by a string ID or by a `%Product{}`.

  If getting by a `%Product{}`, both `:product_id` and `:unit_price`
  must match.
  """
  @spec get_suborder(%__MODULE__{}, %Product{}) :: %SubOrder{} | nil
  def get_suborder(order, %Product{} = prod) when is_list(order.suborders) do
    Enum.find(
      order.suborders,
      &(&1.product_id == prod.id and &1.unit_price == prod.unit_price)
    )
  end

  @spec get_suborder(%__MODULE__{}, String.t()) :: %SubOrder{} | nil
  def get_suborder(order, suborder_id) when is_list(order.suborders) do
    Enum.find(order.suborders, &("#{&1.id}" == suborder_id))
  end

  @doc """
  Fetch one field of `:product` in all `:suborders` of the same `order`.

  This requires the `order` to have preloaded `:suborders`,
  and each of these sub-orders to have a preloaded `:product`.
  """
  @spec product_field_values!(%__MODULE__{}, atom()) :: [any()]
  def product_field_values!(order, product_field) do
    Enum.map(order.suborders, &Map.fetch!(&1.product, product_field))
  end

  @doc """
  Determine whether an order is deletable. A user can delete
  only own unpaid orders. An admin can delete any unpaid orders.
  """
  @spec deletable?(%__MODULE__{}, %User{}) :: boolean()
  def deletable?(%__MODULE__{} = order, %User{} = user) do
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
  @spec changeset_with_already_paid_error(%__MODULE__{}, String.t()) ::
          %Changeset{}
  defp changeset_with_already_paid_error(
         %__MODULE__{} = order,
         msg \\ "the order has been paid for"
       ) do
    order
    |> change()
    |> add_error(:paid, msg, [validation: :paid_unpaid])
  end

  # The key is `"user_id"` or `:user_id`.
  @spec maybe_put_user_id(%Changeset{}, %Order{}, attrs()) :: %Changeset{}
  defp maybe_put_user_id(set, order, attrs) when is_map(attrs) do
    case has_attr?(attrs, :user_id) do
      true -> maybe_put_user_id(set, order, get_attr(attrs, :user_id))
      false -> set
    end
  end

  # `attrs` contain an integer `"user_id"` or `:user_id`.
  @spec maybe_put_user_id(%Changeset{}, %Order{}, non_neg_integer()) ::
          %Changeset{}
  defp maybe_put_user_id(changeset, order, user_id) when is_integer(user_id) do
    maybe_put_user_id(changeset, order, "#{user_id}")
  end

  # `attrs` contain a string `"user_id"` or `:user_id`.
  @spec maybe_put_user_id(%Changeset{}, %Order{}, String.t()) :: %Changeset{}
  defp maybe_put_user_id(changeset, order, user_id) when is_binary(user_id) do
    case "#{order.user_id}" != user_id do
      true -> put_change(changeset, :user_id, user_id)
      false -> changeset
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

  @spec maybe_validate_required(%Changeset{}, [atom()], attrs()) ::
          %Changeset{}
  defp maybe_validate_required(set, fields, attrs) when is_map(attrs) do
    maybe_validate_required(set, fields, get_attr(attrs, :paid))
  end

  @spec maybe_validate_required(%Changeset{}, [atom()], String.t()) ::
          %Changeset{}
  defp maybe_validate_required(set, fields, paid) when is_binary(paid) do
    maybe_validate_required(set, fields, to_boolean(paid))
  end

  # Require `fields` only when "Paid" is checked.
  @spec maybe_validate_required(%Changeset{}, [atom()], boolean() | nil) ::
          %Changeset{}
  defp maybe_validate_required(set, fields, true = _paid?) do
    validate_required(set, fields, [message: "can't be blank in a paid order"])
  end

  # `attrs` do not contain `"paid"` or `:paid`,
  # whichever is contained has a value of `nil` (maybe both of them do),
  # or the "Paid" check box is unchecked.
  defp maybe_validate_required(set, _flds, paid?) when paid? in [nil, false] do
    set
  end

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

  # The changeset has errors.
  @spec maybe_clear_paid_at(%Changeset{}, attrs()) :: %Changeset{}
  defp maybe_clear_paid_at(%{errors: errors} = set, _att) when errors != [] do
    set
  end

  # The changeset is valid. The key is `"paid"` or `:paid`.
  defp maybe_clear_paid_at(changeset, attrs) when is_map(attrs) do
    maybe_clear_paid_at(changeset, get_attr(attrs, :paid))
  end

  # The value of `"paid"` or `:paid` is a string.
  @spec maybe_clear_paid_at(%Changeset{}, String.t()) :: %Changeset{}
  defp maybe_clear_paid_at(changeset, paid) when is_binary(paid) do
    maybe_clear_paid_at(changeset, to_boolean(paid))
  end

  # The "Paid" check box is unchecked,
  # set the change of `:paid_at` to `nil`.
  @spec maybe_clear_paid_at(%Changeset{}, boolean() | nil) :: %Changeset{}
  defp maybe_clear_paid_at(set, false), do: put_change(set, :paid_at, nil)

  # `attrs` do not contain `"paid"` and `:paid`,
  # whichever is contained has a value of `nil` (maybe both of them do),
  # or the "Paid" check box is checked, this means
  # do not clear `paid_at`.
  defp maybe_clear_paid_at(set, paid?) when paid? in [nil, true], do: set

  # Expects each sub-order to have filled `:subtotal`.
  @spec fill_total(%__MODULE__{}) :: %__MODULE__{}
  defp fill_total(%__MODULE__{} = order) when is_list(order.suborders) do
    total =
      Enum.reduce(order.suborders, Decimal.new("0.00"), fn suborder, acc ->
        acc
        |> Decimal.add(suborder.subtotal)
        |> Decimal.round(2)
      end)

    Map.replace(order, :total, total)
  end
end
