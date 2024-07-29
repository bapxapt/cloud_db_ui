defmodule CloudDbUiWeb.UserLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.{Accounts, DataCase}
  alias CloudDbUi.Accounts.User
  alias Phoenix.LiveViewTest.View

  import CloudDbUi.{AccountsFixtures, OrdersFixtures}
  import Phoenix.LiveViewTest

  @type html_or_redirect() :: CloudDbUi.Type.html_or_redirect()

  describe "Index, a not-logged-in guest" do
    setup [:create_user]

    test "gets redirected away", %{conn: conn, other_user: user} do
      assert_redirect_to_log_in_page(live(conn, ~p"/users"))
      assert_redirect_to_log_in_page(live(conn, ~p"/users/new"))
      assert_redirect_to_log_in_page(live(conn, ~p"/users/#{user}/edit"))
    end
  end

  describe "Index, a user" do
    setup [:register_and_log_in_user, :create_user]

    test "gets redirected away", %{conn: conn, other_user: user} do
      assert_redirect_to_main_page(live(conn, ~p"/users"))
      assert_redirect_to_main_page(live(conn, ~p"/users/new"))
      assert_redirect_to_main_page(live(conn, ~p"/users/#{user}/edit"))
    end
  end

  describe "Index, an admin" do
    setup [:register_and_log_in_admin, :create_user, :create_admin]

    test "lists all users",
         %{conn: conn, user: self, other_user: user, admin: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert(page_title(index_live) =~ "Listing users")
      assert_table_row_count(index_live, 3)
      assert(has_table_row?(index_live, "#users", self, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))
      assert(has_table_row?(index_live, "#users", admin, [:id, :email]))
    end

    test "saves a new non-admin user", %{conn: conn, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      click(index_live, "div.flex-none > a", "New user")

      assert_patch(index_live, ~p"/users/new")
      assert_form_errors(index_live, user.email)
      assert_label_change(index_live)

      submit(index_live, "#user-form")

      assert_patch(index_live, ~p"/users")
      assert(has_flash?(index_live, :info, "User created successfully."))
      assert_table_row_count(index_live, 4)
    end

    test "updates a user in listing",
         %{conn: conn, admin: admin, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{user.id} a", "Edit")

      assert_patch(index_live, ~p"/users/#{user}/edit")
      assert_table_row_count(index_live, 3)
      assert_form_errors(index_live, admin.email)
      assert_label_change(index_live)

      submit(index_live, "#user-form")

      assert_patch(index_live, ~p"/users")
      assert_table_row_count(index_live, 3)
      assert(has_flash?(index_live, :info, "#{user.id} updated successfully."))
    end

    test "cannot update an admin in listing", %{conn: conn, admin: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{admin.id} a", "Edit")

      assert(has_flash?(index_live, "Cannot edit an administrator."))
      refute(has_element?(index_live, "input#user_email"))
    end

    test "cannot update self in listing", %{conn: conn, user: self} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{self.id} a", "Edit")

      assert(has_flash?(index_live, "Cannot edit self."))
      refute(has_element?(index_live, "input#user_email"))
    end

    test "deletes a user with no paid orders and with zero balance in listing",
         %{conn: conn, other_user: user} do
      order_fixture(%{user: user})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      click(index_live, "#users-#{user.id} a", "Delete")

      assert(has_flash?(index_live, :info, "Deleted user ID #{user.id}"))
      refute(has_element?(index_live, "#users-#{user.id}"))
      assert_table_row_count(index_live, 2)
    end

    test "cannot delete a user with paid orders in listing",
         %{conn: conn, other_user: user} do
      order_fixture(%{user: user, paid: true})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      click(index_live, "#users-#{user.id} a", "Delete")

      index_live
      |> has_flash?("Cannot delete a user that owns any paid orders or has")
      |> assert()

      assert(has_element?(index_live, "#users-#{user.id}"))
      assert_table_row_count(index_live, 3)
    end

    test "cannot delete a user with non-zero balance in listing",
         %{conn: conn} do
      with_balance = user_fixture(%{balance: 100})
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 4)

      click(index_live, "#users-#{with_balance.id} a", "Delete")

      index_live
      |> has_flash?("a user that owns any paid orders or has non-zero balance")
      |> assert()

      assert(has_element?(index_live, "#users-#{with_balance.id}"))
      assert_table_row_count(index_live, 4)
    end

    test "cannot delete an admin in listing", %{conn: conn, admin: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      click(index_live, "#users-#{admin.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete an administrator."))
      assert(has_element?(index_live, "#users-#{admin.id}"))
      assert_table_row_count(index_live, 3)
    end

    test "cannot delete self in listing", %{conn: conn, user: self} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      click(index_live, "#users-#{self.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete self."))
      assert(has_element?(index_live, "#users-#{self.id}"))
      assert_table_row_count(index_live, 3)
    end

    test "filters users by the e-mail address",
         %{conn: conn, admin: admin, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 0, "¢@¢")

      assert_table_row_count(index_live, 0)

      filter(index_live, 0, String.upcase(admin.email))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#users", admin, [:id, :email]))

      filter(index_live, 0, String.upcase(user.email))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))
      assert_filter_form_errors(index_live, 0, "text")
      assert_filter_param_handling(conn, "users", 0, :email_trimmed, :ilike)
    end

    test "filters users by whether the e-mail has been confirmed",
         %{conn: conn, user: self, admin: admin, other_user: user} do
      update_user(self, %{confirmed_at: "2022-01-20 15:00:00Z"})
      update_user(user, %{confirmed_at: "2022-01-20 10:00:00Z"})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 1, true)

      assert_table_row_count(index_live, 2)
      refute(has_table_row?(index_live, "#users", admin, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 1, false)

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#users", admin, [:id, :email]))
      refute(has_table_row?(index_live, "#users", user, [:id, :email]))
      assert_filter_param_handling(conn, "users", 1, :confirmed_at, :==)
    end

    test "filters users by \"Confirmed from\"",
         %{conn: conn, user: self, other_user: user} do
      update_user(self, %{confirmed_at: "2022-01-20 15:00:00Z"})
      update_user(user, %{confirmed_at: "2022-01-20 10:00:00Z"})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 2, "2022-01-20 10:00")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", self, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 2, "2022-01-20 10:01")

      assert_table_row_count(index_live, 1)

      assert(has_table_row?(index_live, "#users", self, [:id, :email]))
      refute(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 2, "2022-01-20 15:01")

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 2, 3, "datetime-local")
      assert_filter_param_handling(conn, "users", 2, :confirmed_at, :>=)
    end

    test "filters users by \"Confirmed to\"",
         %{conn: conn, user: self, other_user: user} do
      update_user(self, %{confirmed_at: "2022-01-20 15:00:00Z"})
      update_user(user, %{confirmed_at: "2022-01-20 10:00:00Z"})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 3, "2022-01-20 15:00")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", self, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 3, "2022-01-20 10:00")

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#users", self, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 3, "2022-01-20 09:59")

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 3, 2, "datetime-local")
      assert_filter_param_handling(conn, "users", 3, :confirmed_at, :<=)
    end

    test "filters users by \"Registered from\"",
         %{conn: conn, admin: self, other_user: user} do
      DataCase.update_inserted_at(self, "2020-02-15 15:00:00Z")
      DataCase.update_inserted_at(user, "2020-02-15 10:00:00Z")

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 4, "2020-02-15 10:00")

      assert_table_row_count(index_live, 3)
      assert(has_table_row?(index_live, "#users", self, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 4, "2020-02-15 10:01")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", self, [:id, :email]))
      refute(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 4, "2020-02-15 15:01")

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#users", self, [:id, :email]))
      refute(has_table_row?(index_live, "#users", user, [:id, :email]))
      assert_filter_form_errors(index_live, 4, 5, "datetime-local")
      assert_filter_param_handling(conn, "users", 4, :inserted_at, :>=)
    end

    test "filters users by \"Registered to\"",
         %{conn: conn, admin: self, other_user: user} do
      DataCase.update_inserted_at(self, "2020-02-15 15:00:00Z")
      DataCase.update_inserted_at(user, "2020-02-15 10:00:00Z")

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 5, "2020-02-15 15:00")

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", self, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 5, "2020-02-15 14:59")

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#users", self, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 5, "2020-02-15 09:59")

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 5, 4, "datetime-local")
      assert_filter_param_handling(conn, "users", 5, :inserted_at, :<=)
    end

    test "filters users by \"Balance from\"", %{conn: conn} do
      [poor, rich] = Enum.map([1, 10], &user_fixture(%{balance: &1}))
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 5)

      filter(index_live, 6, poor.balance)

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", rich, [:id, :email]))
      assert(has_table_row?(index_live, "#users", poor, [:id, :email]))

      filter(index_live, 6, Decimal.add(poor.balance, "0.01"))

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#users", rich, [:id, :email]))
      refute(has_table_row?(index_live, "#users", poor, [:id, :email]))

      filter(index_live, 6, Decimal.add(rich.balance, "0.01"))

      assert_table_row_count(index_live, 0)
      assert_filter_form_errors(index_live, 6, 7, "decimal")
      assert_filter_param_handling(conn, "users", 6, :balance_trimmed, :>=)
    end

    test "filters users by \"Balance to\"",
         %{conn: conn, user: current_user, admin: admin} do
      [poor, rich] = Enum.map([1, 10], &user_fixture(%{balance: &1}))
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 5)

      filter(index_live, 7, Decimal.sub(rich.balance, "0.01"))

      assert_table_row_count(index_live, 4)
      refute(has_table_row?(index_live, "#users", rich, [:id, :email]))
      assert(has_table_row?(index_live, "#users", poor, [:id, :email]))

      filter(index_live, 7, Decimal.sub(poor.balance, "0.01"))

      assert_table_row_count(index_live, 3)
      refute(has_table_row?(index_live, "#users", rich, [:id, :email]))
      refute(has_table_row?(index_live, "#users", poor, [:id, :email]))

      filter(index_live, 7, 0)

      assert_table_row_count(index_live, 3)
      assert(has_table_row?(index_live, "#users", admin, [:id, :email]))
      assert(has_table_row?(index_live, "#users", current_user, [:id, :email]))
      assert_filter_form_errors(index_live, 7, 6, "decimal")
      assert_filter_param_handling(conn, "users", 7, :balance_trimmed, :<=)
    end

    test "filters users by whether a user is active",
         %{conn: conn, admin: active, other_user: user} do
      update_user(user, %{active: false})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 8, true)

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", active, [:id, :email]))
      refute(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 8, false)

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#users", active, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))
      assert_filter_param_handling(conn, "users", 8, :active, :==)
    end

    test "filters users by whether a user is an administrator",
         %{conn: conn, admin: admin, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 3)

      filter(index_live, 9, true)

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", admin, [:id, :email]))
      refute(has_table_row?(index_live, "#users", user, [:id, :email]))

      filter(index_live, 9, false)

      assert_table_row_count(index_live, 1)
      refute(has_table_row?(index_live, "#users", admin, [:id, :email]))
      assert(has_table_row?(index_live, "#users", user, [:id, :email]))
      assert_filter_param_handling(conn, "users", 9, :admin, :==)
    end

    test "filters users by whether a user has any orders",
         %{conn: conn, admin: admin, other_user: orderless} do
      [with_unpaid, with_paid] = Enum.map(0..1, fn _ -> user_fixture() end)

      order_fixture(%{user: with_unpaid})
      order_fixture(%{user: with_paid, paid: true})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 5)

      filter(index_live, 10, true)

      assert_table_row_count(index_live, 2)
      assert(has_table_row?(index_live, "#users", with_paid, [:id, :email]))
      assert(has_table_row?(index_live, "#users", with_unpaid, [:id, :email]))
      refute(has_table_row?(index_live, "#users", admin, [:id, :email]))
      refute(has_table_row?(index_live, "#users", orderless, [:id, :email]))

      filter(index_live, 10, false)

      assert_table_row_count(index_live, 3)
      refute(has_table_row?(index_live, "#users", with_paid, [:id, :email]))
      refute(has_table_row?(index_live, "#users", with_unpaid, [:id, :email]))
      assert(has_table_row?(index_live, "#users", admin, [:id, :email]))
      assert(has_table_row?(index_live, "#users", orderless, [:id, :email]))
      assert_filter_param_handling(conn, "users", 10, :has_orders, :!=)
    end

    test "filters users by whether a user has any paid orders",
         %{conn: conn, admin: admin, other_user: orderless} do
      [with_unpaid, with_paid] = Enum.map(0..1, fn _ -> user_fixture() end)
      {:ok, index_live, _html} = live(conn, ~p"/users")

      order_fixture(%{user: with_unpaid})
      order_fixture(%{user: with_paid, paid: true})

      assert_table_row_count(index_live, 5)

      filter(index_live, 11, true)

      assert_table_row_count(index_live, 1)
      assert(has_table_row?(index_live, "#users", with_paid, [:id, :email]))

      filter(index_live, 11, false)

      assert_table_row_count(index_live, 4)
      assert(has_table_row?(index_live, "#users", admin, [:id, :email]))
      assert(has_table_row?(index_live, "#users", orderless, [:id, :email]))
      assert(has_table_row?(index_live, "#users", with_unpaid, [:id, :email]))
      refute(has_table_row?(index_live, "#users", with_paid, [:id, :email]))
      assert_filter_param_handling(conn, "users", 11, :has_paid_orders, :!=)
    end

    test "sorts users by the ID",
         %{conn: conn, user: self, admin: admin, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_sorting(index_live, [self.id, user.id, admin.id], "ID")
      assert_sort_param_handling(conn, "users", :id)
    end

    test "sorts users by e-mail",
         %{conn: conn, user: self, admin: admin, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_sorting(
        index_live,
        [self.email, admin.email, user.email],
        ~r/^\s*?E-mail\s*$/
      )

      assert_sort_param_handling(conn, "users", :email)
    end

    test "sorts users by the registration date",
         %{conn: conn, user: self, admin: admin, other_user: user} do
      values =
        Enum.map([{self, 15}, {admin, 20}, {user, 10}], fn {usr, hour} ->
          value = "2020-02-15 #{hour}:00:00"
          {:ok, _updated} = DataCase.update_inserted_at(usr, value <> "Z")

          value
        end)

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_sorting(index_live, values, "Registration date and time")
      assert_sort_param_handling(conn, "users", :inserted_at)
    end

    test "sorts users by the e-mail confirmation date",
         %{conn: conn, user: self, admin: admin, other_user: user} do
      values =
        Enum.map([{self, 15}, {admin, 20}, {user, 10}], fn {usr, hour} ->
          value = "2020-02-20 #{hour}:00:00"
          {:ok, _updated} = update_user(usr, %{confirmed_at: value <> "Z"})

          value
        end)

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_sorting(index_live, values, "E-mail confirmation date and time")
      assert_sort_param_handling(conn, "users", :confirmed_at)
    end

    test "sorts users by the balance", %{conn: conn, other_user: user} do
      Accounts.update_user(user, %{balance: 5})
      user_fixture(%{balance: 10})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_sorting(index_live, [0, 10, 0, 5], "Balance")
      assert_sort_param_handling(conn, "users", :balance)
    end

    test "sorts users by whether they are active",
         %{conn: conn, other_user: user} do
      update_user(user, %{active: false})
      user_fixture(%{active: false})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_sorting(index_live, ["Yes", "", "Yes", ""], "Active")
      assert_sort_param_handling(conn, "users", :active)
    end

    test "sorts users by whether they are administrators", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_sorting(index_live, ["Yes", "", "Yes"], "Administrator")
      assert_sort_param_handling(conn, "users", :admin)
    end

    test "sorts users by multiple columns", %{conn: conn} do
      Enum.each(0..2, fn _ -> user_fixture(%{balance: 5}) end)

      params_by_balance_id = order_params([:balance, :id], [:asc, :desc])
      {:ok, index_live, _html} = live(conn, ~p"/users?#{params_by_balance_id}")
      ids_desc = column_values(index_live, 1)

      # "Balance, PLN" column values.
      assert(sorted?(column_values(index_live, 5)))
      assert_table_row_count(index_live, 6)
      assert(sorted?(Enum.take(ids_desc, 3), :desc))
      assert(sorted?(Enum.take(ids_desc, -3), :desc))
      refute(sorted?(ids_desc, :desc))

      params_by_admin_id = order_params([:admin, :id], [:desc, :asc])
      {:ok, live, _html} = live(conn, ~p"/users?#{params_by_admin_id}")
      ids_asc = column_values(live, 1)

      # "Administrator" column values.
      assert(column_values(live, 7) == ["Yes", "Yes", "", "", "", ""])
      assert(sorted?(Enum.take(ids_asc, 2), :asc))
      assert(sorted?(Enum.take(ids_asc, -4), :asc))
      refute(sorted?(ids_asc, :asc))
    end

    test "switches between pages of user results", %{conn: conn} do
      Enum.each(0..22, fn _ -> user_fixture() end)

      {:ok, index_live, _html} = live(conn, ~p"/users")

      assert_table_row_count(index_live, 25)
      assert(has_n_children?(index_live, "nav.pagination > ul", 2))

      index_live
      |> has_element?("#pagination-counter", "26 results (25 on the current")
      |> assert()

      {:ok, live, _html} = live(conn, ~p"/users")

      click(live, "nav.pagination > ul > :nth-child(2) > a")

      assert_table_row_count(live, 1)

      live
      |> has_element?("#pagination-counter", "26 results (1 on the current")
      |> assert()

      assert_page_param_handling(conn, "users")
    end
  end

  describe "Show, a not-logged-in guest" do
    setup [:create_user]

    test "gets redirected away", %{conn: conn, other_user: user} do
      assert_redirect_to_log_in_page(live(conn, ~p"/users/#{user}"))
      assert_redirect_to_log_in_page(live(conn, ~p"/users/#{user}/show"))
      assert_redirect_to_log_in_page(live(conn, ~p"/users/#{user}/show/edit"))
    end
  end

  describe "Show, a user" do
    setup [:register_and_log_in_user, :create_user]

    test "gets redirected away", %{conn: conn, other_user: user} do
      assert_redirect_to_main_page(live(conn, ~p"/users/#{user}"))
      assert_redirect_to_main_page(live(conn, ~p"/users/#{user}/show"))
      assert_redirect_to_main_page(live(conn, ~p"/users/#{user}/show/edit"))
    end
  end

  describe "Show, an admin" do
    setup [:register_and_log_in_admin, :create_user, :create_admin]

    test "displays any user",
         %{conn: conn, user: self, other_user: user, admin: admin} do
      {:ok, show_live_self, _html} = live(conn, ~p"/users/#{self}")

      assert(list_item_value(show_live_self, "E-mail address") == self.email)

      {:ok, show_live_user, _html} = live(conn, ~p"/users/#{user}")

      assert(list_item_value(show_live_user, "E-mail address") == user.email)

      {:ok, show_live_admin, _html} = live(conn, ~p"/users/#{admin}")

      assert(list_item_value(show_live_admin, "E-mail address") == admin.email)
    end

    test "updates a user within modal", %{conn: conn, other_user: user} do
      {:ok, show_live, _html} = live(conn, ~p"/users/#{user}")

      click(show_live, "div.flex-none > a", "Edit")

      assert_patch(show_live, ~p"/users/#{user}/show/edit")
      assert_form_errors(show_live, user_fixture().email)
      assert_label_change(show_live)

      submit(show_live, "#user-form")

      assert_patch(show_live, ~p"/users/#{user}")
      assert(has_flash?(show_live, :info, "#{user.id} updated successfully"))
    end

    test "cannot update an admin within modal", %{conn: conn, admin: admin} do
      {:ok, show_live, _html} = live(conn, ~p"/users/#{admin}")

      click(show_live, "div.flex-none > a", "Edit")

      assert(has_flash?(show_live, "Cannot edit an administrator."))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end

    test "cannot update self within modal", %{conn: conn, user: self} do
      {:ok, show_live, _html} = live(conn, ~p"/users/#{self}")

      click(show_live, "div.flex-none > a", "Edit")

      assert(has_flash?(show_live, "Cannot edit self."))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end

    test "deletes a user with no paid orders and with zero balance",
         %{conn: conn, other_user: user} do
      order_fixture(%{user: user})

      {:ok, show_live, _html} = live(conn, ~p"/users/#{user}")

      {:ok, index_live, _html} =
        show_live
        |> click("div.flex-none > a", "Delete")
        |> follow_redirect(conn, ~p"/users")

      assert(has_flash?(index_live, :info, "Deleted user ID #{user.id}"))
      refute(has_element?(index_live, "#users-#{user.id}"))
      assert_table_row_count(index_live, 2)
    end

    test "cannot delete a user with paid orders",
         %{conn: conn, other_user: user} do
      order_fixture(%{user: user, paid: true})

      {:ok, show_live, _html} = live(conn, ~p"/users/#{user}")

      click(show_live, "div.flex-none > a", "Delete")

      show_live
      |> has_flash?("annot delete a user that owns any paid orders or has")
      |> assert()

      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end

    test "cannot delete a user with non-zero balance", %{conn: conn} do
      with_balance = user_fixture(%{balance: 100})
      {:ok, show_live, _html} = live(conn, ~p"/users/#{with_balance}")

      click(show_live, "div.flex-none > a", "Delete")

      show_live
      |> has_flash?("a user that owns any paid orders or has non-zero balance")
      |> assert()

      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end

    test "cannot delete an admin", %{conn: conn, admin: admin} do
      {:ok, show_live, _html} = live(conn, ~p"/users/#{admin}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_flash?(show_live, "Cannot delete an administrator."))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end

    test "cannot delete self", %{conn: conn, user: self} do
      {:ok, show_live, _html} = live(conn, ~p"/users/#{self}")

      click(show_live, "div.flex-none > a", "Delete")

      assert(has_flash?(show_live, "Cannot delete self."))
      assert(has_element?(show_live, "div.flex-none > a", "Delete"))
    end
  end

  @spec assert_form_errors(%View{}, String.t()) :: boolean()
  defp assert_form_errors(%View{} = live, taken_email) do
    assert(form_errors(live, "#user-form") == [])
    assert_form_email_errors(live, "#user-form", taken_email)
    assert_form_email_confirmation_errors(live, "new@new.pl")

    if has_element?(live, "#user-form button", "Change password") do
      click(live, "#user-form button", "Change password")
    end

    assert_form_password_errors(live, "#user-form")

    if has_element?(live, "input#user_confirmed_at") do
      assert_datetime_field_errors(live, "#user-form", :user, :confirmed_at)

      change_form(live, %{confirmed_at: ~U[2012-12-20 12:00:00Z]})
    end

    assert_decimal_field_errors(live, "#user-form", :user, :balance)

    change_form(live, %{balance: -1})

    assert(has_form_error?(live, "#user-form", :balance, "ust not be negativ"))

    live
    |> change_form(%{balance: Decimal.add(User.balance_limit(), "0.01")})
    |> assert_match("must be less than or equal to #{User.balance_limit()}")

    change_form(live, %{balance: 123.45})

    assert(form_errors(live, "#user-form") == [])
  end

  @spec assert_form_email_confirmation_errors(%View{}, String.t) :: boolean()
  defp assert_form_email_confirmation_errors(%View{} = live, email) do
    change(live, "#user-form", %{user: %{email_confirmation: "~=+^1"}})

    live
    |> has_form_error?("#user-form", :email_confirmation, "does not match con")
    |> assert()

    change(live, "#user-form", %{user: %{email_confirmation: " " <> email}})

    assert(form_errors(live, "#user-form", :email_confirmation) == [])
    assert(email != String.upcase(email))

    change(
      live,
      "#user-form",
      %{user: %{email_confirmation: "  " <> String.upcase(email) <> "   "}}
    )

    assert(form_errors(live, "#user-form", :email_confirmation) == [])
    assert(email != String.capitalize(email))

    change(
      live,
      "#user-form",
      %{user: %{email_confirmation: "   " <> String.capitalize(email) <> " "}}
    )

    assert(form_errors(live, "#user-form", :email_confirmation) == [])
  end

  # Should return a rendered `#user-form`.
  @spec change_form(%View{}, %{atom() => any()}) :: html_or_redirect()
  defp change_form(%View{} = live_view, user_data) do
    change(live_view, "#user-form", %{user: user_data})
  end

  @spec assert_label_change(%View{}) :: boolean()
  defp assert_label_change(%View{} = live) do
    assert_user_email_label_change(live, "#user-form")
    assert_user_email_confirmation_label_change(live, "#user-form")
    assert_user_password_label_change(live, "#user-form")
  end

  # `&Accounts.update_user/2` requires `:balance` to not be blank.
  @spec update_user(%User{}, %{atom() => any()}) ::
          {:ok, %User{}} | {:error, %Ecto.Changeset{}}
  defp update_user(%User{} = user, attrs) do
    Accounts.update_user(user, Enum.into(attrs, %{balance: user.balance}))
  end
end
