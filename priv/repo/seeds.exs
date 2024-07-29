# Script for populating the data base. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly.

## Users

[
  %{
    email: "a@a.pl",
    password: "Test1234",
    admin: true
  },
  %{
    email: "a2@a2.pl",
    password: "Test1234",
    admin: true
  },
  %{
    email: "u@u.pl",
    password: "Test1234"
  },
  %{
    email: "u2@u2.pl",
    password: "Test1234"
  },
  %{
    email: "inactive@inactive.pl",
    password: "Test1234",
    active: false
  }
]
|> Enum.map(&CloudDbUi.Accounts.create_user/1)
|> Enum.filter(fn {result, _} -> result == :error end)
|> Enum.each(fn {:error, changeset} -> IO.inspect(changeset) end)

## Product types

[
  %{
    name: "Household chemicals",
    description: "Detergents, shampoo, antiseptics, etc.",
  },
  %{
    name: "Kitchenware",
    description: "Dishes, utensils, cookware, etc.",
  },
  %{
    name: "Groceries",
    description: "Food, beverages, supplements.",
  },
  %{
    name: "test type (no desc)"
  },
  %{
    name: "disabled",
    assignable: false
  }
]
|> Enum.map(&CloudDbUi.Products.create_product_type/1)
|> Enum.filter(fn {result, _} -> result == :error end)
|> Enum.each(fn {:error, changeset} -> IO.inspect(changeset) end)

## Products

[
  %{
    product_type_id: 1,
    name: "Window cleaner",
    description: "Instantly cleans a window with just one sprayer shot.",
    unit_price: Decimal.new("22.99")
  },
  %{
    product_type_id: 3,
    name: "Goat cheese",
    description: "From the famous \"Groaning Goat\" brand.",
    unit_price: Decimal.new("100.00")
  },
  %{
    product_type_id: 3,
    name: "Chicken eggs",
    description: "A carton of 6 eggs from plump free-range chickens.",
    unit_price: Decimal.new("8.86")
  },
  %{
    product_type_id: 2,
    name: "Aurora cutlery",
    description: "A set of 14 silver forks and knives.",
    unit_price: Decimal.new("97.40")
  },
  %{
    product_type_id: 2,
    name: "test product (no desc)",
    unit_price: Decimal.new("0.00")
  },
  %{
    product_type_id: 1,
    name: "non-orderable",
    unit_price: Decimal.new("0.00"),
    orderable: false
  }
]
|> Enum.map(&CloudDbUi.Products.create_product/1)
|> Enum.filter(fn {result, _} -> result == :error end)
|> Enum.each(fn {:error, changeset} -> IO.inspect(changeset) end)

## Orders

[
  %{user_id: 3, paid: true, paid_at: ~U[2024-03-15T12:30:00.000+00]},
  %{user_id: 3},
  %{user_id: 3, paid: true, paid_at: ~U[2024-05-10T09:00:00.000+00]},
  %{user_id: 2, paid: true, paid_at: ~U[2024-06-19T16:25:00.000+00]},
  %{user_id: 2},
  %{user_id: 3}
]
|> Enum.map(&CloudDbUi.Orders.create_order/1)
|> Enum.filter(fn {result, _} -> result == :error end)
|> Enum.each(fn {:error, changeset} -> IO.inspect(changeset) end)

## Sub-orders

[
  %{order_id: 1, product_id: 1, quantity: 10},
  %{order_id: 2, product_id: 2, quantity: 1},
  %{order_id: 3, product_id: 4, quantity: 3},
  %{order_id: 4, product_id: 3, quantity: 4},
  %{order_id: 5, product_id: 4, quantity: 6},
  %{order_id: 5, product_id: 3, quantity: 1},
  %{order_id: 6, product_id: 5, quantity: 1}
]
|> Enum.map(fn attrs ->
  product = CloudDbUi.Products.get_product!(attrs.product_id)

  Map.put_new(attrs, :unit_price, product.unit_price)
end)
|> Enum.map(&CloudDbUi.Orders.create_suborder/1)
|> Enum.filter(fn {result, _} -> result == :error end)
|> Enum.each(fn {:error, changeset} -> IO.inspect(changeset) end)
