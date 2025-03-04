defmodule CloudDbUiWeb.UserRegistrationLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      assert(has_element?(lv, "input#user_email"))
      assert(has_element?(lv, "input#user_password"))
      assert(has_element?(lv, "input#user_password_confirmation"))
      assert(has_element?(lv, "button", "Create an account"))
    end

    test "redirects if already logged in", %{conn: conn} do
      {:ok, _conn} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/register")
        |> follow_redirect(conn, ~p"/")
        |> assert()
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      assert_form_email_errors(lv, "#registration-form")
      assert_form_password_errors(lv, "#registration-form")
      assert_user_email_label_change(lv, "#registration-form")
      assert_user_password_label_change(lv, "#registration-form")
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      email =
        unique_email()
        |> String.upcase()

      form =
        form(
          lv,
          "#registration-form",
          %{user: %{email: "  #{email}  ", password: valid_password()}}
        )

      render_submit(form)

      conn_new = follow_trigger_action(form, conn)

      assert(redirected_to(conn_new) == ~p"/")

      {:ok, index_live, html} =
        conn_new
        |> live(~p"/")
        |> follow_redirect(conn_new, ~p"/products")

      assert(html =~ String.downcase(email))
      assert(html =~ "Settings")
      assert(html =~ "Log out")
      assert(has_flash?(index_live, :info, "Account created successfully"))
    end

    test "renders errors for a duplicated e-mail", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/register")

      submit(
        lv,
        "#registration-form",
        %{user: %{email: "  " <> String.upcase(user.email) <> "   "}}
      )

      assert(user.email != String.upcase(user.email))

      lv
      |> has_form_error?("#registration-form", :email, "as already been taken")
      |> assert()
    end
  end

  describe "registration navigation" do
    test "redirects when \"Log in\" is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      {:ok, conn_new} =
        lv
        |> click(~s|main a:fl-contains("Log in")|)
        |> follow_redirect(conn, ~p"/log_in")

      assert(conn_new.resp_body =~ "Log in to account")
    end
  end
end
