defmodule CloudDbUiWeb.UserLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.Accounts.User
  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest
  import CloudDbUi.{AccountsFixtures, OrdersFixtures}

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
      assert(has_element?(index_live, "#users-#{self.id}"))
      assert(has_element?(index_live, "#users-#{user.id}"))
      assert(has_element?(index_live, "#users-#{admin.id}"))
    end

    test "saves a new non-admin user", %{conn: conn, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "div.flex-none > a", "New user")

      assert_patch(index_live, ~p"/users/new")
      assert_form_errors(index_live, user.email)
      assert_label_change(index_live)

      submit(index_live, "#user-form")

      assert_patch(index_live, ~p"/users")
      assert(has_flash?(index_live, :info, "User created successfully."))
    end

    test "updates a user in listing", %{conn: conn, other_user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{user.id} a", "Edit")

      assert_patch(index_live, ~p"/users/#{user}/edit")
      assert_form_errors(index_live, user_fixture().email)
      assert_label_change(index_live)

      submit(index_live, "#user-form")

      assert_patch(index_live, ~p"/users")
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

      click(index_live, "#users-#{user.id} a", "Delete")

      assert(has_flash?(index_live, :info, "Deleted user ID #{user.id}"))
      refute(has_element?(index_live, "#user-#{user.id}"))
    end

    test "cannot delete a user with paid orders in listing",
         %{conn: conn, other_user: user} do
      order_fixture(%{user: user, paid: true})

      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{user.id} a", "Delete")

      index_live
      |> has_flash?("Cannot delete a user that owns any paid orders or has")
      |> assert()

      assert(has_element?(index_live, "#users-#{user.id}"))
    end

    test "cannot delete a user with non-zero balance in listing",
         %{conn: conn} do
      with_balance = user_fixture(%{balance: 100})
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{with_balance.id} a", "Delete")

      index_live
      |> has_flash?("a user that owns any paid orders or has non-zero balance")
      |> assert()

      assert(has_element?(index_live, "#users-#{with_balance.id}"))
    end

    test "cannot delete an admin in listing", %{conn: conn, admin: admin} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{admin.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete an administrator."))
      assert(has_element?(index_live, "#users-#{admin.id}"))
    end

    test "cannot delete self in listing", %{conn: conn, user: self} do
      {:ok, index_live, _html} = live(conn, ~p"/users")

      click(index_live, "#users-#{self.id} a", "Delete")

      assert(has_flash?(index_live, "Cannot delete self."))
      assert(has_element?(index_live, "#users-#{self.id}"))
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
        |> follow_redirect(conn)

      assert(has_flash?(index_live, :info, "Deleted user ID #{user.id}"))
      refute(has_element?(index_live, "#users-#{user.id}"))
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
  defp assert_form_errors(live, existing_email) do
    assert(form_errors(live, "#user-form") == [])
    assert_form_email_errors(live, "#user-form", existing_email)
    assert_form_email_confirmation_errors(live, "new@new.pl")

    if has_element?(live, "#user-form button", "Change password") do
      click(live, "#user-form button", "Change password")
    end

    assert_form_password_errors(live, "#user-form")

    if has_element?(live, "input#user_confirmed_at") do
      change_form(live, %{confirmed_at: ~U[2999-01-01 00:00:00.000+00]})

      live
      |> has_form_error?("#user-form", :confirmed_at, "n&#39;t be in the futu")
      |> assert()

      change_form(live, %{confirmed_at: ~U[2012-12-12 12:00:00.000+00]})
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
end
