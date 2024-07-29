# A script for populating the data base. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly.

alias CloudDbUi.Repo
alias CloudDbUi.Accounts.User
alias CloudDbUi.Products.{Product, ProductType}
alias CloudDbUi.Orders.Order

fn_inspect_invalid_changesets = fn creation_results ->
  creation_results
  |> Enum.filter(fn {status, _} -> status == :error end)
  |> Enum.each(fn {:error, changeset} -> IO.inspect(changeset) end)
end

## User creation.

[_admin, _admin_2, user, user_2, _inactive] =
  [
    %{email: "a@a.pl", admin: true},
    %{email: "a2@a2.pl", admin: true},
    %{email: "u@u.pl"},
    %{email: "u2@u2.pl"},
    %{email: "inactive@inactive.pl", active: false}
  ]
  |> Enum.map(fn attrs ->
    case Repo.get_by(User, attrs) do
      nil ->
        attrs
        |> Map.put_new(:email_confirmation, attrs.email)
        |> Map.put_new(:password, "Test1234")
        |> Map.put_new(:password_confirmation, "Test1234")
        |> Map.put_new(:balance, 0.00)
        |> CloudDbUi.Accounts.create_user()

      existing_user ->
        {:ok, existing_user}
    end
  end)
  |> tap(fn_inspect_invalid_changesets)
  |> Enum.map(fn {:ok, created} -> created end)

## Product type creation.

[type_chem, type_ware, type_groc, _type_no_desc, _type_unassign] =
  [
    %{
      name: "Household chemicals",
      description: "Detergents, shampoo, antiseptics, etc."
    },
    %{name: "Kitchenware", description: "Dishes, utensils, cookware, etc."},
    %{name: "Groceries", description: "Food, beverages, supplements."},
    %{name: "test type (no desc)"},
    %{name: "disabled", assignable: false}
  ]
  |> Enum.map(fn attrs ->
    attrs_no_desc = Map.delete(attrs, :description)

    case Repo.get_by(ProductType, attrs_no_desc) do
      nil -> CloudDbUi.Products.create_product_type(attrs)
      existing_type -> {:ok, existing_type}
    end
  end)
  |> tap(fn_inspect_invalid_changesets)
  |> Enum.map(fn {:ok, created} -> created end)

## Product creation.

[cleaner, cheese, eggs, cutlery, test_prod, _non_orderable] =
  [
    %{
      product_type: type_chem,
      name: "Window cleaner",
      description: "Instantly cleans a window with just one sprayer shot.",
      unit_price: 22.99
    },
    %{
      product_type: type_groc,
      name: "Goat cheese",
      description: "From the famous \"Groaning Goat\" brand.",
      unit_price: 100
    },
    %{
      product_type: type_groc,
      name: "Chicken eggs",
      description: "A carton of 6 eggs from plump free-range chickens.",
      unit_price: 8.86
    },
    %{
      product_type: type_ware,
      name: "Aurora cutlery",
      description: "A set of 14 silver forks and knives.",
      unit_price: 97.40
    },
    %{
      product_type: type_ware,
      name: "test product (no desc)",
      unit_price: 0
    },
    %{
      product_type: type_chem,
      name: "non-orderable",
      unit_price: 0,
      orderable: false
    }
  ]
  |> Enum.map(fn %{product_type: type} = attrs ->
    attrs_new =
      attrs
      |> Map.put_new(:product_type_id, type.id)
      |> Map.delete(:product_type)

    attrs_no_desc = Map.delete(attrs_new, :description)

    case Repo.get_by(Product, attrs_no_desc) do
      nil -> CloudDbUi.Products.create_product(attrs_new, type)
      existing_product -> {:ok, existing_product}
    end
  end)
  |> tap(fn_inspect_invalid_changesets)
  |> Enum.map(fn {:ok, created} -> created end)

## Order creation.

[ord_1, ord_2, ord_3, ord_4, ord_5, ord_6] =
  [%{user: user, orders: 4}, %{user: user_2, orders: 2}]
  |> Enum.flat_map(fn %{user: owner, orders: count_to_create} ->
    orders = CloudDbUi.Orders.list_orders_with_suborder_products(owner)

    empty_orders =
      orders
      |> Enum.filter(&(&1.suborders == [] and !&1.paid_at))
      |> Enum.take(count_to_create)

    if length(orders) < count_to_create do
      for _ <- 1..(count_to_create - length(empty_orders)) do
        CloudDbUi.Orders.create_order(%{user_id: owner.id}, owner)
      end
      |> Kernel.++(Enum.map(empty_orders, &{:ok, &1}))
    else
      # The user already has at least as many orders as `count_to_create`
      # (paid and unpaid).
      List.duplicate({:ok, nil}, count_to_create)
    end
  end)
  |> tap(fn_inspect_invalid_changesets)
  |> Enum.map(fn {:ok, created} -> created end)

## Order position (sub-order) creation.

[
  %{order: ord_1, product: cleaner, quantity: 10},
  %{order: ord_2, product: cheese, quantity: 1},
  %{order: ord_3, product: cutlery, quantity: 3},
  %{order: ord_4, product: test_prod, quantity: 1},
  %{order: ord_5, product: eggs, quantity: 4},
  %{order: ord_6, product: cutlery, quantity: 6},
  %{order: ord_6, product: eggs, quantity: 1}
]
|> Enum.map(fn %{order: order, product: product} = attrs ->
  case order do
    nil ->
      {:ok, nil}

    non_nil_order ->
      attrs
      |> Map.put_new(:order_id, non_nil_order.id)
      |> Map.put_new(:product_id, product.id)
      |> Map.put_new(:unit_price, product.unit_price)
      |> Map.delete(:order)
      |> Map.delete(:product)
      |> CloudDbUi.Orders.create_suborder(non_nil_order, product)
  end
end)
|> fn_inspect_invalid_changesets.()

## Updating unpaid orders to paid for.

[
  {ord_1, %{paid_at: ~U[2024-03-15 12:30:00.123+00]}, user},
  {ord_3, %{paid_at: ~U[2024-05-10 09:00:00.456+00]}, user},
  {ord_5, %{paid_at: ~U[2024-06-19 16:00:00.789+00]}, user_2}
]
|> Enum.map(fn {order, attrs, owner} ->
  cond do
    !order ->
      {:ok, nil}

    order.user_id != owner.id ->
      raise("An incorrect owner is provided for the order ID #{order.id}.")

    true ->
      case Repo.get_by(Order, Map.put_new(attrs, :user_id, owner.id)) do
        nil ->
          CloudDbUi.Orders.update_order(
            order,
            Map.put_new(attrs, :paid, true),
            owner
          )

        any ->
          {:ok, any}
      end
  end
end)
|> fn_inspect_invalid_changesets.()
