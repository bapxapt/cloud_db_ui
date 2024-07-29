defmodule CloudDbUiWeb.UserForgotPasswordLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  alias CloudDbUi.Accounts
  alias CloudDbUi.Repo

  describe "Forgot password page" do
    test "renders e-mail page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      assert(has_element?(lv, "button", "Send password reset instructions"))
      assert(has_element?(lv, ~s|a[href="#{~p"/users/register"}"]|, "Registe"))
      assert(has_element?(lv, ~s|a[href="#{~p"/users/log_in"}"]|, "Log in"))
    end

    test "redirects if already logged in", %{conn: conn} do
      {:ok, _conn} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/reset_password")
        |> follow_redirect(conn, ~p"/")
        |> assert()
    end
  end

  describe "Reset link" do
    setup do
      %{user: user_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", user: %{"email" => "  " <> user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("If your e-mail is in our system")

      token = Repo.get_by!(Accounts.UserToken, [user_id: user.id])

      assert(token.context == "reset_password")
    end

    test "does not send reset password token if email is invalid",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", %{user: %{"email" => "who@nope.com"}})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("If your e-mail is in our system")

      assert(Repo.all(Accounts.UserToken) == [])
    end
  end
end
