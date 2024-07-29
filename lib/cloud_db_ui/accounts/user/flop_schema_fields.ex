defmodule CloudDbUi.Accounts.User.FlopSchemaFields do
  import CloudDbUi.FlopFilters

  @doc """
  A list of `:filterable` fields for a `@derive` `Flop.Schema`.
  """
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

  @doc """
  A list of `:sortable` fields for a `@derive` `Flop.Schema`.
  """
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

  @doc """
  Options for `:custom_fields` within `:adapter_opts` of a `@derive`
  `Flop.Schema`.
  """
  @spec custom_field_opts() :: keyword(keyword())
  def custom_field_opts() do
    [
      email_trimmed: custom_field_opts(:trim!, :email, :string, [:ilike]),
      balance_trimmed: custom_decimal_field_opts(),
      has_orders: custom_has_orders_field_opts(:has_orders?),
      has_paid_orders: custom_has_orders_field_opts(:has_paid_orders?)
    ]
  end

  @spec custom_decimal_field_opts() :: keyword()
  defp custom_decimal_field_opts() do
    custom_field_opts(:to_decimal!, :balance, :string, [:>=, :<=])
  end

  @spec custom_has_orders_field_opts(atom()) :: keyword()
  defp custom_has_orders_field_opts(filter_fn_name) do
    custom_field_opts(filter_fn_name, :order, :boolean, [:!=])
  end
end
