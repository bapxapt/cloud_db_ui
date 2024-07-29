defmodule CloudDbUi.Accounts.User.FlopSchemaFields do
  use CloudDbUi.FlopSchemaFields

  @impl true
  @spec filterable_fields() :: [atom()]
  def filterable_fields() do
    [
      :email_trimmed,
      :confirmed_at,
      :inserted_at,
      :balance_trimmed,
      :admin,
      :active,
      :has_orders,
      :has_paid_orders
    ]
  end

  @impl true
  @spec sortable_fields() :: [atom()]
  def sortable_fields() do
    [
      :id,
      :email,
      :inserted_at,
      :confirmed_at,
      :balance,
      :active,
      :admin
    ]
  end

  @impl true
  @spec adapter_opts() :: keyword([atom() | keyword(keyword())])
  def adapter_opts(), do: [custom_fields: custom_field_opts()]

  @impl true
  @spec list_objects(%Flop{}, struct() | nil) ::
          {:ok, {[struct()], %Flop.Meta{}}} | {:error, %Flop.Meta{}}
  def list_objects(%Flop{} = flop, _user) do
    CloudDbUi.Accounts.list_users_with_order_count(flop)
  end

  @impl true
  @spec delete_object_by_id(%Socket{}, String.t()) :: %Socket{}
  def delete_object_by_id(socket, id) do
    CloudDbUiWeb.UserLive.Actions.delete_user(
      socket,
      CloudDbUi.Accounts.get_user_with_order_count!(id)
    )
  end

  @impl true
  @spec min_max_field_labels() :: [{String.t(), String.t()}]
  def min_max_field_labels() do
    [
      {"Confirmed from", "Confirmed to"},
      {"Registered from", "Registered to"},
      {"Balance from", "Balance to"}
    ]
  end

  @impl true
  @spec filter_form_field_opts(struct() | nil) :: keyword(keyword())
  def filter_form_field_opts(_user) do
    [
      email_trimmed: text_field_opts("E-mail address", :ilike),
      confirmed_at: select_field_opts("E-mail confirmed", :not_empty),
      confirmed_at: datetime_field_opts("Confirmed from", :>=),
      confirmed_at: datetime_field_opts("Confirmed to", :<=),
      inserted_at: datetime_field_opts("Registered from", :>=),
      inserted_at: datetime_field_opts("Registered to", :<=),
      balance_trimmed: balance_field_opts(:>=),
      balance_trimmed: balance_field_opts(:<=),
      active: select_field_opts("Active"),
      admin: select_field_opts("Administrator"),
      has_orders: select_field_opts("Has orders", :!=),
      has_paid_orders: select_field_opts("Has paid orders", :!=)
    ]
  end

  @spec custom_field_opts() :: keyword(keyword())
  defp custom_field_opts() do
    [
      email_trimmed: custom_text_field_opts(:email),
      balance_trimmed: custom_decimal_field_opts(:balance),
      has_orders: custom_has_objects_field_opts(:order),
      has_paid_orders: custom_has_objects_field_opts(:order, :paid_at)
    ]
  end

  @spec balance_field_opts(atom()) :: keyword()
  defp balance_field_opts(:>=) do
    decimal_field_opts("Balance from", :>=, "0.00")
  end

  defp balance_field_opts(:<=) do
    decimal_field_opts("Balance to", :<=, User.balance_limit())
  end
end
