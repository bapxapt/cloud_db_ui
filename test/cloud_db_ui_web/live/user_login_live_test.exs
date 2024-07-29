defmodule CloudDbUiWeb.UserLoginLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  alias Phoenix.LiveViewTest.{View, Element}

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      assert(has_element?(lv, "button", "Log in"))

      lv
      |> has_element?(
        ~s|a[href="#{~p"/users/reset_password"}"]|,
        "Forgot your password?"
      )
      |> assert()
    end

    test "redirects if already logged in", %{conn: conn} do
      {:ok, _conn} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/log_in")
        |> follow_redirect(conn, "/")
        |> assert()
    end
  end

  describe "user login" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      pass = "1234.Abcd"
      user = user_fixture(%{password: pass, password_confirmation: pass})
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      conn_new =
        lv
        |> log_in_form(%{email: " " <> user.email <> "  ", password: pass})
        |> submit_form(conn)

      assert(redirected_to(conn_new) == ~p"/")
    end

    test "redirects to the same page with a flash if no valid credentials",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      conn_new =
        lv
        |> log_in_form(%{email: "absent@absent.com", password: "short"})
        |> submit_form(conn)

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("Invalid e-mail or password.")

      assert(redirected_to(conn_new) == "/users/log_in")
    end

    test "redirects to the same page with a flash if the user is inactive",
         %{conn: conn} do
      pw = "123456789Abc."

      user =
        user_fixture(%{password: pw, password_confirmation: pw, active: false})

      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      conn_new =
        lv
        |> log_in_form(%{email: " " <> user.email <> "  ", password: pw})
        |> submit_form(conn)

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("The account has been deactivated.")

      assert(redirected_to(conn_new) == "/users/log_in")
    end
  end

  describe "login navigation" do
    test "redirects when \"Register\" is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      {:ok, conn_new} =
        lv
        |> element(~s|main a:fl-contains("Sign up")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert(conn_new.resp_body =~ "Create an account")
    end

    test "redirects when \"Forgot your password?\" is clicked",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      {:ok, conn_new} =
        lv
        |> element(~s|main a:fl-contains("Forgot your password?")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/reset_password")

      assert(conn_new.resp_body =~ "Send password reset instructions")
    end
  end

  @spec log_in_form(%View{}, %{atom() => any()}) :: %Element{}
  def log_in_form(%View{} = live, user_data) do
    form(
      live,
      "#log-in-form",
      %{user: Enum.into(user_data, %{remember_me: true})}
    )
  end
end
