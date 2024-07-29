defmodule CloudDbUiWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use CloudDbUiWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.{Product, ProductType}
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias CloudDbUi.{ProductsFixtures, OrdersFixtures, AccountsFixtures}
  alias Phoenix.LiveViewTest.View

  @type form_data() :: keyword(%{atom() => any()}) | %{atom() => %{atom() => any()}}
  @type redirect() :: CloudDbUi.Type.redirect()

  using do
    quote do
      # The default endpoint for testing
      @endpoint CloudDbUiWeb.Endpoint

      use CloudDbUiWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import CloudDbUiWeb.ConnCase
    end
  end

  setup tags do
    CloudDbUi.DataCase.setup_sandbox(tags)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn} = _context) do
    user = AccountsFixtures.user_fixture(%{balance: Decimal.new("6000.00")})

    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that registers and logs in administrators.

      setup :register_and_log_in_admin

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_admin(%{conn: conn} = _context) do
    admin = AccountsFixtures.user_fixture(%{admin: true})

    %{conn: log_in_user(conn, admin), user: admin}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  @spec log_in_user(%Plug.Conn{}, %User{}) :: %Plug.Conn{}
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(
      :user_token,
      CloudDbUi.Accounts.generate_user_session_token(user)
    )
  end

  @doc """
  Retrieve the current value of an input field from rendered HTML.
  """
  @spec input_value(%View{}, String.t()) :: String.t()
  def input_value(%View{} = live_view, input_id) do
    ~r/(?<=value=\")[^\"]/
    |> Regex.run(render(live_view, "input" <> input_id))
    |> hd()
  end

  @doc """
  `render_click()` an `element()` within a `live_view`.
  """
  @spec click(%View{}, String.t(), String.t() | nil) ::
          String.t() | {:error, {:redirect, redirect()}}
  def click(%View{} = live_view, selector, text_filter \\ nil) do
    live_view
    |> Phoenix.LiveViewTest.element(selector, text_filter)
    |> Phoenix.LiveViewTest.render_click()
  end

  @doc """
  `render_change()` a `form()` with `form_data`.
  """
  @spec change(%View{}, String.t(), form_data()) ::
          String.t() | {:error, {:redirect, redirect()}}
  def change(%View{} = live_view, selector, form_data) do
    live_view
    |> Phoenix.LiveViewTest.form(selector, form_data)
    |> Phoenix.LiveViewTest.render_change()
  end

  @doc """
  `render_submit()` `form_data` into a `form()`.
  """
  @spec submit(%View{}, String.t(), form_data()) ::
          String.t() | {:error, {:redirect, redirect()}}
  def submit(%View{} = live_view, selector, form_data \\ %{}) do
    live_view
    |> Phoenix.LiveViewTest.form(selector, form_data)
    |> Phoenix.LiveViewTest.render_submit()
  end

  @doc """
  `render()` an element()` selected with a `selector`.
  """
  @spec render(%View{}, String.t(), String.t() | nil) :: String.t()
  def render(%View{} = live_view, selector, text_filter \\ nil) do
    live_view
    |> Phoenix.LiveViewTest.element(selector, text_filter)
    |> Phoenix.LiveViewTest.render()
  end

  @doc """
  Determine whether a `live_view` has a flash of `kind` with a title
  containing a `title_part`.
  """
  @spec has_flash?(%View{}, atom() | String.t(), String.t()) :: boolean()
  def has_flash?(%View{} = live_view, kind \\ :error, title_part) do
    live_view
    |> Phoenix.LiveViewTest.has_element?("#flash-#{kind}")
    |> Kernel.and(Phoenix.LiveViewTest.render(live_view) =~ title_part)
  end

  @doc """
  Determine whether a `value` matches an `expression`.
  If an `expression` is a string, check whether `value` contains it.
  """
  @spec assert_match(String.t(), %Regex{} | String.t()) :: boolean()
  def assert_match(value, expression), do: assert(value =~ expression)

  # TODO: a dialyzer issue with refute() (returns boolean() | nil)?

  @doc """
  A negated `assert_match()`. Returns `true` if a `value`
  does not match an `expression`.
  """
  @spec refute_match(String.t(), %Regex{} | String.t()) :: boolean()
  def refute_match(value, expression), do: refute(value =~ expression)

  @doc """
  Check that invalid input causes an appropriate error to be displayed.
  """
  @spec assert_suborder_form_errors(%View{}) :: boolean()
  def assert_suborder_form_errors(%View{} = live_view) do
    # TODO:
    assert(false)
  end

  @doc """
  Check that "Subtotal" gets recalculated when `:quantity` changes.
  """
  @spec assert_suborder_subtotal_change(%View{}, %SubOrder{}) :: boolean()
  def assert_suborder_subtotal_change(%View{} = live, %{quantity: qty}) do
    qty_new =
      case qty < SubOrder.quantity_limit() do
        true -> qty + 1
        false -> qty - 1
      end
      |> to_string()

    live
    |> change("#suborder-form", %{sub_order: %{quantity: qty_new}})
    |> assert_match(
      "#{Decimal.mult(input_value(live, "#sub_order_unit_price"), qty_new)}"
    )
  end

  @doc """
  Create an order within a test `context`.
  """
  @spec create_order(%{atom() => any()}) :: %{order: %Order{}}
  def create_order(%{user: user} = _context) do
    %{order: OrdersFixtures.order_fixture(%{user_id: user.id})}
  end

  # Creates a user, but does not put this user into the `context`.
  def create_order(_context), do: %{order: OrdersFixtures.order_fixture()}

  @doc """
  Create a paid order within a test `context`.
  """
  @spec create_paid_order(%{atom() => any()}) :: %{order: %Order{}}
  def create_paid_order(%{user: user} = _context) do
    %{order: OrdersFixtures.order_paid_fixture(%{user_id: user.id})}
  end

  # Creates a user, but does not put this user into the `context`.
  def create_paid_order(_context) do
    %{order: OrdersFixtures.order_paid_fixture()}
  end

  @doc """
  Create a sub-order within a test `context`. Creates a product
  and a product type, but does not put them into the `context`.
  """
  @spec create_suborder(%{atom() => any()}) :: %{suborder: %SubOrder{}}
  def create_suborder(%{order: order} = _context) do
    %{suborder: OrdersFixtures.suborder_fixture(%{order_id: order.id})}
  end

  # Creates an order, a product, and a product_type, but does not put
  # them into the `context`.
  def create_suborder(_context) do
    %{suborder: OrdersFixtures.suborder_fixture()}
  end

  @doc """
  Create a product within a test `context`.
  """
  @spec create_product(%{atom() => any()}) :: %{product: %Product{}}
  def create_product(%{type: type} = _context) do
    %{product: ProductsFixtures.product_fixture(%{product_type_id: type.id})}
  end

  # Creates a product type, but does not put it into the `context`.
  def create_product(_context) do
    %{product: ProductsFixtures.product_fixture()}
  end

  @doc """
  Create a product type within a test `context`.
  """
  @spec create_product_type(%{atom() => any()}) :: %{type: %ProductType{}}
  def create_product_type(_context) do
    %{type: ProductsFixtures.product_type_fixture()}
  end

  @doc """
  Create an non-assignable product type within a test `context`.
  """
  @spec create_unassignable_product_type(%{atom() => any()}) ::
          %{type: %ProductType{}}
  def create_unassignable_product_type(_context) do
    %{type: ProductsFixtures.product_type_fixture(%{assignable: false})}
  end
end
