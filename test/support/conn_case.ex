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

  use Phoenix.VerifiedRoutes,
    endpoint: CloudDbUiWeb.Endpoint,
    router: CloudDbUiWeb.Router

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Products.{Product, ProductType}
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias CloudDbUi.{ProductsFixtures, OrdersFixtures, AccountsFixtures}
  alias Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.View

  import CloudDbUiWeb.Utilities

  require Phoenix.LiveViewTest

  @type text_filter() :: String.t() | %Regex{} | nil
  @type form_data() :: keyword(%{atom() => any()}) | %{atom() => %{atom() => any()}}
  @type redirect() :: CloudDbUi.Type.redirect()
  @type html_or_redirect() :: CloudDbUi.Type.html_or_redirect()
  @type upload_entry() :: CloudDbUi.Type.upload_entry()

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
    pass = AccountsFixtures.valid_password()
    user = AccountsFixtures.user_fixture(%{balance: 6000, password: pass})

    %{conn: log_in_user(conn, user), user: user, password: pass}
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
  @spec input_value(%View{}, atom(), text_filter()) :: String.t()
  def input_value(%View{} = live_view, field, text_filter \\ nil) do
    live_view
    |> render(selector(:input, field), text_filter)
    |> attribute_value(:value)
  end

  @doc """
  Retrieve a list of `<select>` options for a `field`.
  """
  @spec options_of_select(%View{}, atom(), text_filter()) ::
          %{String.t() => String.t()}
  def options_of_select(%View{} = live_view, field, text_filter \\ nil) do
    ~r/(?<=value=\")[^<]*(?=<\/option>)/
    |> Regex.scan(render(live_view, selector(:select, field), text_filter))
    |> List.flatten()
    |> Enum.map(&String.trim/1)
    |> Map.new(fn option ->
      option
      |> String.split("\">")
      |> List.to_tuple()
    end)
  end

  @doc """
  Retrieve a list of form error text strings.
  A `field` can be passed to narrow down the results.
  """
  @spec form_errors(%View{}, String.t(), atom()) :: [String.t()]
  def form_errors(%View{} = live_view, form_selector, field) do
    live_view
    |> render(form_selector <> " div[phx-feedback-for$='[#{field}]']")
    |> form_errors()
  end

  @spec form_errors(%View{}, String.t()) :: [String.t()]
  def form_errors(%View{} = live_view, form_selector) do
    live_view
    |> render(form_selector)
    |> form_errors()
  end

  @spec form_errors(String.t()) :: [String.t()]
  def form_errors(rendered) when is_binary(rendered) do
    ~r/(?<="><\/span>)[^<]*(?=<)/
    |> Regex.scan(rendered)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
  end

  @doc """
  Retrieve the title of a `<.list>` item.
  """
  @spec list_item_title(%View{}, String.t(), String.t()) :: String.t() | nil
  def list_item_title(%View{} = live, selector \\ "dl > div", text_filter) do
    live
    |> render(selector, text_filter)
    |> tag_content(:dt)
  end

  @doc """
  Retrieve the value of a `<.list>` item.
  """
  @spec list_item_value(%View{}, String.t(), String.t()) :: String.t() | nil
  def list_item_value(%View{} = live, selector \\ "dl > div", text_filter) do
    live
    |> render(selector, text_filter)
    |> tag_content(:dd)
  end

  @doc """
  Retrieve the text of a `<.label>` for a `field` input.
  """
  @spec label_text(%View{}, atom(), text_filter()) :: String.t() | nil
  def label_text(%View{} = live_view, field, text_filter \\ nil) do
    live_view
    |> render(selector(:label, field), text_filter)
    |> tag_content(:label)
  end

  @doc """
  Retrieve the value of the `src` attribute for an `<img>` tag.
  """
  @spec img_src(%View{}, String.t()) :: String.t()
  def img_src(%View{} = live_view, selector) do
    live_view
    |> render(selector)
    |> attribute_value(:src)
  end

  @doc """
  Retrieve the value of `<progress>` for a `live_file_input()`.
  """
  @spec upload_progress(%View{}) :: String.t()
  def upload_progress(
        %View{} = live_view,
        selector \\ "div[phx-drop-target] > progress"
      ) do
    live_view
    |> render(selector)
    |> attribute_value(:value)
  end

  @doc """
  `render_click()` an `element()` within a `live_view`.
  """
  @spec click(%View{}, String.t(), text_filter()) :: html_or_redirect()
  def click(%View{} = live_view, selector, text_filter \\ nil) do
    live_view
    |> LiveViewTest.element(selector, text_filter)
    |> LiveViewTest.render_click()
  end

  @doc """
  `render_change()` a `form()` with `form_data`.
  """
  @spec change(%View{}, String.t(), form_data()) :: html_or_redirect()
  def change(%View{} = live_view, selector, form_data) do
    live_view
    |> LiveViewTest.form(selector, form_data)
    |> LiveViewTest.render_change()
  end

  @doc """
  `render_submit()` `form_data` into a `form()`.
  """
  @spec submit(%View{}, String.t(), form_data()) :: html_or_redirect()
  def submit(%View{} = live_view, selector, form_data \\ %{}) do
    live_view
    |> LiveViewTest.form(selector, form_data)
    |> LiveViewTest.render_submit()
  end

  @doc """
  `render()` an element()` selected with a `selector`.
  """
  @spec render(%View{}, String.t(), text_filter()) :: String.t()
  def render(%View{} = live_view, selector, text_filter \\ nil) do
    live_view
    |> LiveViewTest.element(selector, text_filter)
    |> LiveViewTest.render()
  end

  @doc """
  `render_upload()` a `file_input()` in a form.
  """
  @spec upload(%View{}, String.t(), atom(), upload_entry()) ::
          html_or_redirect()
  def upload(%View{} = live, form_selector, upload_name, entry) do
    live
    |> LiveViewTest.file_input(form_selector, upload_name, [entry])
    |> LiveViewTest.render_upload(entry[:name])
  end

  @doc """
  Determine whether a check box is checked. The check box has to exist.
  """
  @spec checked?(%View{}, atom() | String.t()) :: boolean()
  def checked?(%View{} = live_view, field) do
    live_view
    |> render(selector(:input, field) <> "[type=checkbox]")
    |> attribute_value(:checked)
    |> case do
      nil -> false
      _any -> true
    end
  end

  @doc """
  Determine whether a `live_view` has a `<.list>` item matching
  a `text_filter`.
  """
  @spec has_list_item?(%View{}, text_filter()) :: boolean()
  def has_list_item?(%View{} = live_view, text_filter \\ nil) do
    LiveViewTest.has_element?(live_view, "dl > div", text_filter)
  end

  @doc """
  Determine whether a `live_view` has a flash of `kind` with a title
  containing matching a `text_filter`.
  """
  @spec has_flash?(%View{}, atom() | String.t(), text_filter()) :: boolean()
  def has_flash?(%View{} = live_view, kind \\ :error, text_filter) do
    LiveViewTest.has_element?(live_view, "div#flash-#{kind} > p", text_filter)
  end

  @doc """
  Determine whether a `live_view` has a `<.table>` cell (`<td>`)
  matching a `text_filter`.
  """
  @spec has_table_cell?(%View{}, String.t(), text_filter()) :: boolean()
  def has_table_cell?(%View{} = live_view, class \\ "relative", text_filter) do
    LiveViewTest.has_element?(
      live_view,
      "td span[class='#{class}']",
      text_filter
    )
  end

  @doc """
  Determine whether a `live_view` has a `<.header>` matching
  a `text_filter`.
  """
  @spec has_header?(%View{}, text_filter()) :: boolean()
  def has_header?(%View{} = live_view, text_filter \\ nil) do
    LiveViewTest.has_element?(live_view, "header > div > h1", text_filter)
  end

  @doc """
  Retrieve potential errors for an `upload_name` of a form selected
  by `form_selector` if an upload `entry` gets uploaded.
  """
  @spec upload_errors(%View{}, String.t(), atom(), upload_entry()) :: [atom()]
  def upload_errors(%View{} = live, form_selector, upload_name, entry) do
    live
    |> LiveViewTest.file_input(form_selector, upload_name, [entry])
    |> LiveViewTest.preflight_upload()
    |> elem(1)
    |> Map.fetch!(:errors)
    |> Map.values()
    |> List.flatten()
  end

  @doc """
  Determine whether a form has an error containing `error_part`.
  A `field` can be passed to narrow down the results.
  """
  @spec has_form_error?(%View{}, String.t(), atom(), String.t()) :: boolean()
  def has_form_error?(%View{} = live_view, form_selector, field, error_part) do
    live_view
    |> form_errors(form_selector, field)
    |> Enum.any?(&(&1 =~ error_part))
  end

  @spec has_form_error?(%View{}, String.t(), String.t()) :: boolean()
  def has_form_error?(%View{} = live_view, form_selector, error_part) do
    live_view
    |> form_errors(form_selector)
    |> Enum.any?(&(&1 =~ error_part))
  end

  @doc """
  Create an upload entry from a real readable file
  to be used with `file_input()`.
  """
  @spec upload_entry!(String.t()) :: upload_entry()
  def upload_entry!(file_path \\ "./deps/phoenix/priv/static/phoenix.png") do
    %{
      last_modified: 1_594_171_879_000,
      name: Path.basename(file_path),
      type: content_type(Path.basename(file_path)),
      content: File.read!(file_path)
    }
  end

  @doc """
  Return an upload entry to be used with `file_input()`.
  Its content is just a string.
  """
  @spec upload_entry(String.t(), non_neg_integer()) :: upload_entry()
  def upload_entry(file_name, file_size) do
    %{
      last_modified: 1_594_171_879_000,
      name: file_name,
      type: content_type(file_name),
      size: file_size,
      content: String.duplicate(".", file_size)
    }
  end

  @doc """
  Determine whether a string `value` matches a `pattern`.
  If the `pattern` is a string, check whether `value` contains it.
  """
  @spec assert_match(String.t(), %Regex{} | String.t()) :: boolean()
  def assert_match(value, pattern), do: assert(value =~ pattern)

  # TODO: a dialyzer issue with refute()

  @doc """
  A negated `assert_match()`. Returns `true` if a `value`
  does not match an `expression`.
  """
  @spec refute_match(String.t(), %Regex{} | String.t()) :: boolean()
  def refute_match(value, pattern), do: refute(value =~ pattern)

  @doc """
  Check that a user gets redirected to the log-in page with an expected
  flash message.
  """
  @spec assert_redirect_to_log_in_page({:error, {:redirect, redirect()}}) ::
          boolean()
  def assert_redirect_to_log_in_page({:error, {:redirect, redirect}}) do
    assert(redirect.to == ~p"/users/log_in")
    assert(redirect.flash["error"] =~ "You must log in to access this page.")
  end

  @doc """
  Check that a user gets redirected to the main page with an expected
  flash message.
  """
  @spec assert_redirect_to_main_page(
          {:error, {:redirect, redirect()}},
          String.t()
        ) :: boolean()
  def assert_redirect_to_main_page(
        {:error, {:redirect, redirect}},
        flash_title \\ "Only an administrator may access"
      ) do
    assert(redirect.to == ~p"/")
    assert(redirect.flash["error"] =~ flash_title)
  end

  @doc """
  Assert common decimal field errors:

    - blank;
    - not a number;
    - more than two decimal digits;
    - scientific;
    - has non-digit characters except for one dot between the integer part
      and the fractional part (no dot if there is only the integer part,
      also cannot begin with a dot instead of a zero).
  """
  @spec assert_decimal_field_errors(%View{}, String.t(), atom(), atom()) ::
          boolean()
  def assert_decimal_field_errors(%View{} = live, form_id, object, field) do
    change(live, form_id, %{object => %{field => nil}})

    assert(has_form_error?(live, form_id, field, "can&#39;t be blank"))

    change(live, form_id, %{object => %{field => "_w"}})

    assert(has_form_error?(live, form_id, field, "is invalid"))

    change(live, form_id, %{object => %{field => "2.500"}})

    assert(has_form_error?(live, form_id, field, "invalid format"))

    change(live, form_id, %{object => %{field => ".12"}})

    assert(has_form_error?(live, form_id, field, "invalid format"))

    change(live, form_id, %{object => %{field => "3."}})

    assert(has_form_error?(live, form_id, field, "invalid format"))

    change(live, form_id, %{object => %{field => "1e2"}})

    assert(has_form_error?(live, form_id, field, "invalid format"))

    change(live, form_id, %{object => %{field => "1E3"}})

    assert(has_form_error?(live, form_id, field, "invalid format"))
  end

  @doc """
  Check that invalid input causes an appropriate error to be displayed
  in the `:email` field of a form selected with `form_id`.
  """
  @spec assert_form_email_errors(%View{}, String.t(), text_filter()) ::
          boolean()
  def assert_form_email_errors(%View{} = live, form_id, existing \\ nil) do
    long_email = String.duplicate("a", 62) <> "@" <> String.duplicate("b", 99)

    change(live, form_id, %{user: %{email: long_email}})

    assert(has_form_error?(live, form_id, :email, "hould be at most 160"))

    change(live, form_id, %{user: %{email: nil}})

    assert(has_form_error?(live, form_id, :email, "can&#39;t be blank"))

    if existing do
      change(live, form_id, %{user: %{email: "  " <> existing <> " "}})

      assert(has_form_error?(live, form_id, :email, "already been taken"))
      assert(existing != String.capitalize(existing))

      change(
        live,
        form_id,
        %{user: %{email: "   " <> String.capitalize(existing) <> "  "}}
      )

      assert(has_form_error?(live, form_id, :email, "already been taken"))
      assert(existing != String.upcase(existing))

      change(live, form_id, %{user: %{email: " " <> String.upcase(existing)}})

      assert(has_form_error?(live, form_id, :email, "already been taken"))
    end

    change(live, form_id, %{user: %{email: "new@new.pl"}})

    assert(form_errors(live, form_id, :email) == [])
  end

  @doc """
  Check that invalid input causes an appropriate error to be displayed
  in the `:password` field or in the `:password_confirmation` field
  of a form selected with `form_id`.
  """
  @spec assert_form_password_errors(%View{}, String.t()) :: boolean()
  def assert_form_password_errors(%View{} = live, form_id) do
    change(live, form_id, %{user: %{password: "Abc123."}})

    assert(has_form_error?(live, form_id, :password, "at least 8 charac"))

    change(live, form_id, %{user: %{password: "abcd123."}})

    assert(has_form_error?(live, form_id, :password, "least one upper-c"))

    change(live, form_id, %{user: %{password: "ABCD123."}})

    assert(has_form_error?(live, form_id, :password, "least one lower-c"))

    change(live, form_id, %{user: %{password: "AbcdAbcd"}})

    assert(has_form_error?(live, form_id, :password, "t least one digit"))

    change(
      live,
      form_id,
      %{user: %{password: AccountsFixtures.valid_password()}}
    )

    change(live, form_id, %{user: %{password_confirmation: "ABCD1234"}})

    live
    |> has_form_error?(form_id, :password_confirmation, "does not match")
    |> assert()

    change(
      live,
      form_id,
      %{user: %{password_confirmation: AccountsFixtures.valid_password()}}
    )

    assert(form_errors(live, form_id, :password) == [])
    assert(form_errors(live, form_id, :password_confirmation) == [])
  end

  @doc """
  Check that invalid input causes an appropriate error to be displayed
  in `#suborder-form`.
  """
  @spec assert_suborder_form_errors(%View{}, %SubOrder{}) :: boolean()
  def assert_suborder_form_errors(%View{} = live, suborder) do
    assert(form_errors(live, "#suborder-form") == [])
    assert_suborder_form_order_id_errors(live, suborder)

    change_suborder_form(live, %{product_id: nil})

    assert(has_form_error?(live, "#suborder-form", :product_id, "t be blank"))

    change_suborder_form(live, %{product_id: -1})

    live
    |> has_form_error?("#suborder-form", :product_id, "product not found")
    |> assert()

    non_orderable = ProductsFixtures.product_fixture(%{orderable: false})

    change_suborder_form(live, %{product_id: non_orderable.id})

    live
    |> has_form_error?(
      "#suborder-form",
      :product_id,
      "cannot assign a non-orderable product"
    )
    |> assert()

    change_suborder_form(live, %{product_id: suborder.product_id})

    assert(assert(form_errors(live, "#suborder-form", :product_id) == []))
    assert_suborder_form_unit_price_errors(live)
    assert_suborder_form_quantity_errors(live, suborder)
    assert(form_errors(live, "#suborder-form") == [])
  end

  @doc """
  Check that invalid `:quantity` input causes an appropriate error
  to be displayed in `#suborder-form`.
  """
  @spec assert_suborder_form_quantity_errors(%View{}, %SubOrder{}) :: boolean()
  def assert_suborder_form_quantity_errors(%View{} = live, suborder) do
    change_suborder_form(live, %{quantity: nil})

    assert(has_form_error?(live, "#suborder-form", :quantity, "t be blank"))

    change_suborder_form(live, %{quantity: "_w"})

    assert(has_form_error?(live, "#suborder-form", :quantity, "is invalid"))

    change_suborder_form(live, %{quantity: 0})

    live
    |> has_form_error?(
      "#suborder-form",
      :quantity,
      "cannot order fewer than one piece")
    |> assert()

    change_suborder_form(live, %{quantity: SubOrder.quantity_limit() + 1})

    live
    |> has_form_error?(
      "#suborder-form",
      :quantity,
      "cannot order more than #{SubOrder.quantity_limit()}")
    |> assert()

    # Restore an initial value of `:quantity`.
    change_suborder_form(live, %{quantity: suborder.quantity})

    assert(form_errors(live, "#suborder-form", :quantity) == [])
  end

  @doc """
  Check that "Subtotal" gets recalculated when `:quantity`
  and `:unit_price` (if the input field is present) changes.
  """
  @spec assert_suborder_subtotal_change(%View{}, %SubOrder{}) ::
          html_or_redirect()
  def assert_suborder_subtotal_change(%View{} = live, suborder) do
    assert_suborder_subtotal_change(
      live,
      suborder,
      LiveViewTest.has_element?(live, "#sub_order_unit_price")
    )
  end

  @doc """
  Check that the label of the `:user_id` input field changes
  when a valid user ID in inputted.
  """
  @spec assert_suborder_order_id_label_change(%View{}, %SubOrder{}) ::
          boolean()
  def assert_suborder_order_id_label_change(%View{} = live_view, suborder) do
    user = CloudDbUi.AccountsFixtures.user_fixture()
    unpaid = OrdersFixtures.order_fixture(%{user: user})
    paid = OrdersFixtures.order_fixture(%{user: user, paid: true})

    change_suborder_form(live_view, %{order_id: paid.id})

    live_view
    |> label_text(:order_id)
    |> assert_match("(paid, belongs to ID #{user.id} #{user.email})")

    change_suborder_form(live_view, %{order_id: unpaid.id})

    live_view
    |> label_text(:order_id)
    |> assert_match("(unpaid, belongs to ID #{user.id} #{user.email})")

    change_suborder_form(live_view, %{order_id: suborder.order_id})

    assert(form_errors(live_view, "#suborder-form", :order_id) == [])
  end

  @doc """
  Check that the label of the `:product_id` input field changes
  when a valid user ID in inputted.
  """
  @spec assert_suborder_product_id_label_change(%View{}, %SubOrder{}) ::
          boolean()
  def assert_suborder_product_id_label_change(%View{} = live_view, suborder) do
    orderable =
      ProductsFixtures.product_fixture(%{unit_price: 692.84, name: "warm"})

    non_orderable =
      ProductsFixtures.product_fixture(%{
        orderable: false,
        unit_price: 346.42,
        name: "fence"
      })

    change_suborder_form(live_view, %{product_id: non_orderable.id})

    live_view
    |> label_text(:product_id)
    |> assert_match("ID (non-orderable, &quot;#{non_orderable.name}&quot;)")

    assert(list_item_value(live_view, "Current unit price") == "PLN 346.42")

    change_suborder_form(live_view, %{product_id: orderable.id})

    live_view
    |> label_text(:product_id)
    |> assert_match("ID (orderable, &quot;#{orderable.name}&quot;)")

    assert(list_item_value(live_view, "Current unit price") == "PLN 692.84")

    change_suborder_form(live_view, %{product_id: suborder.product_id})

    assert(form_errors(live_view, "#suborder-form", :product_id) == [])
  end

  @doc """
  Check that the label of the `:email` input field changes
  when input is not blank.
  """
  @spec assert_user_email_label_change(%View{}, String.t()) :: boolean()
  def assert_user_email_label_change(%View{} = live, form_selector) do
    change(live, form_selector, %{user: %{email: nil}})

    live
    |> label_text(:email, "E-mail")
    |> refute_match(~r/(?:, |\()\d+\/\d+\s+characters?\)\s*$/)

    change(live, form_selector, %{user: %{email: "ff@ff.pl"}})

    live
    |> label_text(:email, "E-mail")
    |> assert_match(~r/(?:, |\()8\/160\s+characters?\)\s*$/)
  end

  @doc """
  Check that the label of the `:email_confirmation` input field
  changes when input is not blank.
  """
  @spec assert_user_email_confirmation_label_change(%View{}, String.t()) ::
          boolean()
  def assert_user_email_confirmation_label_change(%View{} = live, form_id) do
    change(live, form_id, %{user: %{email_confirmation: nil}})

    live
    |> label_text(:email_confirmation)
    |> assert_match(~r/^E-mail address confirmation$/)

    change(live, form_id, %{user: %{email_confirmation: "ff@ff.pl"}})

    live
    |> label_text(:email_confirmation)
    |> assert_match("E-mail address confirmation (8/160 characters)")
  end

  @doc """
  Check that the label of the `:password` input field changes
  when input is not blank.
  """
  @spec assert_user_password_label_change(%View{}, String.t()) :: boolean()
  def assert_user_password_label_change(%View{} = live, form_selector) do
    change(live, form_selector, %{user: %{password: nil}})

    live
    |> label_text(:password, ~r/^\s*(?:New p|P)assword/)
    |> refute_match(~r/(?:, |\()\d+\/\d+\s+characters?\)\s*$/)

    change(live, form_selector, %{user: %{password: "Test1234."}})

    live
    |> label_text(:password, ~r/^\s*(?:New p|P)assword/)
    |> assert_match(~r/(?:, |\()9\/72\s+characters?\)\s*$/)

    change(live, form_selector, %{user: %{password_confirmation: nil}})

    live
    |> label_text(:password_confirmation)
    |> refute_match(~r/(?:, |\()\d+\/\d+\s+characters?\)\s*$/)

    change(live, form_selector, %{user: %{password_confirmation: "Test1234."}})

    live
    |> label_text(:password_confirmation)
    |> assert_match(~r/(?:, |\()9\/72\s+characters?\)\s*$/)
  end

  @doc """
  Check that the label of the `:unit_price` input field changes
  when a valid number in inputted.
  """
  @spec assert_suborder_unit_price_label_change(%View{}, %SubOrder{}) ::
          html_or_redirect()
  def assert_suborder_unit_price_label_change(%View{} = live_view, suborder) do
    price =
      live_view
      |> list_item_value("Current unit price of")
      |> String.replace_prefix("PLN ", "")

    change_suborder_form(live_view, %{unit_price: price})

    assert(label_text(live_view, :unit_price) =~ "rrently equal to the curren")

    change_suborder_form(live_view, %{unit_price: Decimal.add(price, "0.01")})

    assert(label_text(live_view, :unit_price) =~ "rrently higher than the cu")

    change_suborder_form(live_view, %{unit_price: Decimal.sub(price, "0.01")})

    assert(label_text(live_view, :unit_price) =~ "rrently lower than the curr")

    change_suborder_form(live_view, %{unit_price: suborder.unit_price})
  end

  @doc """
  `change()` for `"#suborder_form"`. Should returns a rendered form.
  """
  @spec change_suborder_form(%View{}, %{atom() => any()}) :: html_or_redirect()
  def change_suborder_form(%View{} = live_view, suborder_data) do
    change(live_view, "#suborder-form", %{sub_order: suborder_data})
  end

  @doc """
  Create a non-administrator user within a test `context`.
  """
  @spec create_user(%{atom() => any()}) :: %{other_user: %User{}}
  def create_user(_context) do
    %{other_user: AccountsFixtures.user_fixture()}
  end

  @doc """
  Create an administrator user within a test `context`.
  """
  @spec create_admin(%{atom() => any()}) :: %{admin: %User{}}
  def create_admin(_context) do
    %{admin: AccountsFixtures.user_fixture(%{admin: true})}
  end

  @doc """
  Create an order within a test `context`.
  """
  @spec create_order(%{atom() => any()}) :: %{order: %Order{}}
  def create_order(%{user: user} = _context) do
    %{order: OrdersFixtures.order_fixture(%{user: user})}
  end

  # Creates a user, but does not put this user into the `context`.
  def create_order(_context), do: %{order: OrdersFixtures.order_fixture()}

  @doc """
  Create a paid order with a sub-order within a test `context`.
  """
  @spec create_paid_order_with_suborder(%{atom() => any()}) ::
          %{order: %Order{}, suborder: %SubOrder{}}
  def create_paid_order_with_suborder(%{user: user} = context) do
    create_paid_order_with_suborder(context, user)
  end

  # Creates a user, but does not put this user into the `context`.
  def create_paid_order_with_suborder(context) do
    create_paid_order_with_suborder(context, AccountsFixtures.user_fixture())
  end

  @doc """
  Create a sub-order within a test `context`. Creates a product
  and a product type, but does not put them into the `context`.
  """
  @spec create_suborder(%{atom() => any()}) :: %{suborder: %SubOrder{}}
  def create_suborder(%{order: order} = _context) do
    %{suborder: OrdersFixtures.suborder_fixture(%{order: order})}
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
    %{product: ProductsFixtures.product_fixture(%{product_type: type})}
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

  @spec content_type(String.t()) :: String.t()
  defp content_type(file_name) do
    case file_extension(file_name) do
      "jpg" -> "image/jpeg"
      "jpeg" -> "image/jpeg"
      "png" -> "image/png"
      "bmp" -> "image/bmp"
      "gif" -> "image/gif"
      _any -> "application/octet-stream"
    end
  end

  @spec file_extension(String.t()) :: String.t() | nil
  defp file_extension(file_name) do
    case Regex.run(~r/(?<=\.)\S+$/, trim_downcase(file_name)) do
      [extension] -> extension
      nil -> nil
    end
  end

  @spec assert_suborder_form_order_id_errors(%View{}, %SubOrder{}) :: boolean()
  defp assert_suborder_form_order_id_errors(%View{} = live, suborder) do
    change_suborder_form(live, %{order_id: nil})

    assert(has_form_error?(live, "#suborder-form", :order_id, "t be blank"))

    change_suborder_form(live, %{order_id: -1})

    assert(has_form_error?(live, "#suborder-form", :order_id, "rder not foun"))

    change_suborder_form(
      live,
      %{order_id: OrdersFixtures.order_fixture(%{paid: true}).id}
    )

    live
    |> has_form_error?("#suborder-form", :order_id, "order has been paid for")
    |> assert()

    change_suborder_form(live, %{order_id: suborder.order_id})

    assert(assert(form_errors(live, "#suborder-form", :order_id) == []))
  end

  @spec assert_suborder_form_unit_price_errors(%View{}) :: boolean()
  defp assert_suborder_form_unit_price_errors(%View{} = live) do
    assert_decimal_field_errors(
      live,
      "#suborder-form",
      :sub_order,
      :unit_price
    )

    change_suborder_form(live, %{unit_price: -1})

    assert(has_form_error?(live, "#suborder-form", :unit_price, "not be nega"))

    change_suborder_form(
      live,
      %{unit_price: Decimal.add(User.balance_limit(), "0.01")}
    )

    live
    |> has_form_error?(
      "#suborder-form",
      :unit_price,
      "must be less than or equal to #{User.balance_limit()}"
    )
    |> assert()

    change_suborder_form(live, %{unit_price: 120.5})

    assert(assert(form_errors(live, "#suborder-form", :unit_price) == []))
  end

  # When the `:unit_price` input field is present.
  @spec assert_suborder_subtotal_change(%View{}, %SubOrder{}, boolean()) ::
          html_or_redirect()
  defp assert_suborder_subtotal_change(%View{} = live_view, suborder, true) do
    quantity_new = changed_quantity(suborder)

    price_new =
      live_view
      |> input_value(:unit_price)
      |> Decimal.add("0.01")

    live_view
    |> change_suborder_form(%{unit_price: price_new, quantity: quantity_new})
    |> assert_match("PLN #{Decimal.mult(price_new, quantity_new)}")

    # Restore initial values.
    change_suborder_form(
      live_view,
      %{unit_price: suborder.unit_price, quantity: suborder.quantity}
    )
  end

  # When the `:unit_price` input field is absent, it cannot be changed.
  defp assert_suborder_subtotal_change(%View{} = live_view, suborder, false) do
    quantity_new = changed_quantity(suborder)

    live_view
    |> change_suborder_form(%{quantity: quantity_new})
    |> assert_match("PLN #{Decimal.mult(suborder.unit_price, quantity_new)}")

    # Restore an initial value of `:quantity`.
    change_suborder_form(live_view, %{quantity: suborder.quantity})
  end

  # Returns a new quantity converted to a string.
  @spec changed_quantity(%SubOrder{}) :: String.t()
  defp changed_quantity(%SubOrder{quantity: quantity} = _suborder) do
    case quantity < SubOrder.quantity_limit() do
      true -> quantity + 1
      false -> 2
    end
    |> to_string()
  end

  # Puts a paid order and its sub-order into the `context`.
  @spec create_paid_order_with_suborder(%{atom() => any()}, %User{}) ::
          %{order: %Order{}, suborder: %SubOrder{}}
  defp create_paid_order_with_suborder(_context, %User{} = user) do
    order = OrdersFixtures.order_fixture(%{user: user})
    suborder = OrdersFixtures.suborder_fixture(%{order: order})

    %{order: OrdersFixtures.change_to_paid(order, user), suborder: suborder}
  end

  @spec selector(atom(), atom()) :: String.t()
  defp selector(:label, field), do: "label[id$=#{field}-label][for$=#{field}]"

  defp selector(tag, field) when tag in [:input, :select] do
    "#{tag}[id$=#{field}][name$='[#{field}]']"
  end

  # Run a regular expression on a rendered list item (a `<div>`
  # with `<dt>` and `<dd>` in it).
  @spec tag_content(String.t(), atom() | String.t()) :: String.t() | nil
  defp tag_content(rendered, tag) do
    "(?<=\\\">)[^>]*(?=<\\/#{tag}>)"
    |> Regex.compile!()
    |> Regex.run(rendered)
    |> maybe_unwrap()
  end

  # Extract the value of a tag attribute.
  @spec attribute_value(String.t(), atom() | String.t()) :: String.t() | nil
  defp attribute_value(rendered, attribute) do
    "(?<=#{attribute}=\\\")[^\\\"]*"
    |> Regex.compile!()
    |> Regex.run(rendered)
    |> maybe_unwrap()
  end

  @spec maybe_unwrap([String.t()] | nil) :: String.t | nil
  defp maybe_unwrap([value]), do: String.trim(value)

  defp maybe_unwrap(nil), do: nil
end