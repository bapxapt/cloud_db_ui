defmodule CloudDbUiWeb.UserResetPasswordLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  alias CloudDbUi.Accounts

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)

    %{token: token, user: user}
  end

  describe "Reset password page" do
    test "renders the page with a valid token", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password/#{token}")

      assert(has_element?(lv, "button", "Reset password"))
    end

    test "does not render the page with an invalid token", %{conn: conn} do
      {:ok, %{assigns: %{flash: flash}} = _conn_new} =
        conn
        |> live(~p"/reset_password/BAD_TOKEN")
        |> follow_redirect(conn, ~p"/")

      assert(flash["error"] =~ "Reset password link is invalid or it has expi")
    end

    test "renders errors for invalid data", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password/#{token}")

      assert_form_password_errors(lv, "#reset-form")
      assert_user_password_label_change(lv, "#reset-form")
    end
  end

  describe "Reset password" do
    test "resets password once", %{conn: conn, token: token, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password/#{token}")

      {:ok, conn} =
        lv
        |> submit(
          "#reset-form",
          %{user: %{password: "New.1234", password_confirmation: "New.1234"}}
        )
        |> follow_redirect(conn, ~p"/log_in")

      conn.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("Password reset successfully")

      refute(get_session(conn, :user_token))
      assert(Accounts.get_user_by_email_and_password(user.email, "New.1234"))
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password/#{token}")

      submit(
        lv,
        "#reset-form",
        %{user: %{password: "¢", password_confirmation: "not matching"}}
      )

      assert(has_element?(lv, "button", "Reset password"))
      assert(has_form_error?(lv, "#reset-form", :password, "one upper-case"))
      assert(has_form_error?(lv, "#reset-form", :password, "one lower-case"))

      lv
      |> has_form_error?("#reset-form", :password, "digit, space or punctuat")
      |> assert()

      lv
      |> has_form_error?("#reset-form", :password_confirmation, "es not match")
      |> assert()
    end
  end

  describe "Reset password navigation" do
    test "redirects when \"Log in\" is clicked", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password/#{token}")

      {:ok, conn_new} =
        lv
        |> click(~s|main a:fl-contains("Log in")|)
        |> follow_redirect(conn, ~p"/log_in")

      assert(conn_new.resp_body =~ "Log in to account")
    end

    test "redirects when \"Register\" is clicked",
         %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password/#{token}")

      {:ok, conn_new} =
        lv
        |> click(~s|main a:fl-contains("Register")|)
        |> follow_redirect(conn, ~p"/register")

      assert(conn_new.resp_body =~ "Create an account")
    end
  end
end
