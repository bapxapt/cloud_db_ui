defmodule CloudDbUiWeb.UserForgotPasswordLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  alias CloudDbUi.{Accounts, Repo}
  alias Phoenix.LiveViewTest.View

  @type redirect_error() :: CloudDbUi.Type.redirect_error()

  describe "Forgot password page" do
    test "gets rendered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password")

      assert(has_element?(lv, "button", "Send password reset instructions"))
      assert(has_element?(lv, ~s|a[href="#{~p"/register"}"]|, "Registe"))
      assert(has_element?(lv, ~s|a[href="#{~p"/log_in"}"]|, "Log in"))
    end

    test "redirects if already logged in", %{conn: conn} do
      {:ok, _conn} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/reset_password")
        |> follow_redirect(conn, ~p"/")
        |> assert()
    end

    test "displays form errors", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password")

      assert(form_errors(lv, "#forgot-password-form", :email) == [])

      change_form(lv, String.duplicate("¢", 161))
      submit(lv, "#forgot-password-form")

      assert(has_email_form_error?(lv, "invalid e-mail format"))
      assert(has_email_form_error?(lv, "should be at most 160 character(s)"))

      change_form(lv, nil)
      submit(lv, "#forgot-password-form")

      lv
      |> form_errors("#forgot-password-form", :email)
      |> Kernel.==(["can&#39;t be blank"])
      |> assert()
    end
  end

  describe "Reset link" do
    setup do
      %{user: user_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password")

      {:ok, %{assigns: %{flash: flash}} = _conn_new} =
        lv
        |> submit_reset_password_form(" " <> user.email <> " ")
        |> follow_redirect(conn, ~p"/")

      assert(flash["info"] =~ "If your e-mail is in our system")

      token = Repo.get_by!(Accounts.UserToken, [user_id: user.id])

      assert(token.context == "reset_password")
    end

    test "does not send reset password token if an e-mail does not exist",
         %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/reset_password")

      {:ok, %{assigns: %{flash: flash}} = _conn_new} =
        lv
        |> submit_reset_password_form("a" <> user.email)
        |> follow_redirect(conn, ~p"/")

      assert(flash["info"] =~ "If your e-mail is in our system")
      assert(Repo.all(Accounts.UserToken) == [])
    end
  end

  @spec has_email_form_error?(%View{}, String.t()) :: boolean()
  defp has_email_form_error?(%View{} = live_view, error_part) do
    has_form_error?(live_view, "#forgot-password-form", :email, error_part)
  end

  @spec change_form(%View{}, String.t() | nil) :: String.t() | redirect_error()
  defp change_form(%View{} = live_view, e_mail) do
    change(live_view, "#forgot-password-form", %{user: %{email: e_mail}})
  end

  @spec submit_reset_password_form(%View{}, String.t() | nil) ::
          String.t() | redirect_error()
  defp submit_reset_password_form(%View{} = live_view, e_mail) do
    submit(live_view, "#forgot-password-form", %{user: %{email: e_mail}})
  end
end
