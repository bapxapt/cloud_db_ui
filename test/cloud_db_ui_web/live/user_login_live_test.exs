defmodule CloudDbUiWeb.UserLoginLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import CloudDbUi.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.View

  @type redirect_error() :: CloudDbUi.Type.redirect_error()

  describe "Log-in page" do
    test "renders the log-in page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/log_in")

      assert(has_element?(lv, "button", "Log in"))

      lv
      |> has_element?(
        ~s|a[href="#{~p"/reset_password"}"]|,
        "Forgot your password?"
      )
      |> assert()
    end

    test "redirects if already logged in", %{conn: conn} do
      {:ok, _conn_new} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/log_in")
        |> follow_redirect(conn, "/")
        |> assert()
    end

    test "displays form errors", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/log_in")

      assert(form_errors(lv, "#log-in-form", :email) == [])

      change_form(lv, %{email: String.duplicate("¢", 161), password: "a"})

      assert(has_form_error?(lv, "#log-in-form", :email, "nvalid e-mail form"))
      assert(has_form_error?(lv, "#log-in-form", :email, "at most 160 charac"))
      assert(has_form_error?(lv, "#log-in-form", :password, "at least 8 char"))

      errors =
        lv
        |> submit("#log-in-form")
        |> form_errors()

      [
        "invalid e-mail format",
        "should be at most 160 character(s)",
        "should be at least 8 character(s)"
      ]
      |> Enum.all?(&(&1 in errors))
      |> assert()

      change_form(lv, %{email: "ok@k.pl", password: String.duplicate("i", 73)})

      assert(form_errors(lv, "#log-in-form", :email) == [])
      assert(has_form_error?(lv, "#log-in-form", :password, "at most 72 char"))

      change_form(lv, %{email: nil, password: nil})

      assert(form_errors(lv, "#log-in-form", :email) == ["can&#39;t be blank"])
      assert(has_form_error?(lv, "#log-in-form", :password, "&#39;t be blank"))
    end
  end

  describe "user logging in" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      pass = valid_password()
      user = user_fixture(%{password: pass})
      {:ok, lv, _html} = live(conn, ~p"/log_in")

      conn_new =
        submit_log_in_form(
          lv,
          conn,
          %{email: " " <> user.email <> " ", password: pass}
        )

      assert(redirected_to(conn_new) == ~p"/")
    end

    test "redirects to the same page with a flash if no valid credentials",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/log_in")

      conn_new =
        submit_log_in_form(lv, conn, %{email: "¢@¢.com", password: "short"})

      assert(conn_new.assigns.flash["error"] == "Invalid e-mail or password.")
      assert(redirected_to(conn_new) == "/log_in")
    end

    test "redirects to the same page with a flash if the user is inactive",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/log_in")
      pass = valid_password()
      user = user_fixture(%{password: pass, active: false})

      conn_new =
        submit_log_in_form(
          lv,
          conn,
          %{email: " " <> user.email <> " ", password: pass}
        )

      assert(conn_new.assigns.flash["error"] =~ "account has been deactivated")
      assert(redirected_to(conn_new) == "/log_in")
    end
  end

  describe "login navigation" do
    test "redirects when \"Register\" is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/log_in")

      {:ok, conn_new} =
        lv
        |> click(~s|main a:fl-contains("Sign up")|)
        |> follow_redirect(conn, ~p"/register")

      assert(conn_new.resp_body =~ "Create an account")
    end

    test "redirects when \"Forgot your password?\" is clicked",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/log_in")

      {:ok, conn_new} =
        lv
        |> click(~s|main a:fl-contains("Forgot your password?")|)
        |> follow_redirect(conn, ~p"/reset_password")

      assert(conn_new.resp_body =~ "Send password reset instructions")
    end
  end

  @spec change_form(%View{}, %{atom() => any()}) ::
          String.t() | redirect_error()
  defp change_form(%View{} = live_view, user_data) do
    change(live_view, "#log-in-form", %{user: user_data})
  end

  @spec submit_log_in_form(%View{}, %Plug.Conn{}, %{atom() => any()}) ::
          %Plug.Conn{}
  defp submit_log_in_form(%View{} = live_view, conn, usr_data) do
    live_view
    |> form("#log-in-form", %{user: Enum.into(usr_data, %{remember_me: true})})
    |> submit_form(conn)
  end
end
