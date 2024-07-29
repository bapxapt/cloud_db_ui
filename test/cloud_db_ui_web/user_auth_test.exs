defmodule CloudDbUiWeb.UserAuthTest do
  use CloudDbUiWeb.ConnCase, async: true

  alias CloudDbUi.Accounts
  alias CloudDbUiWeb.UserAuth
  alias Phoenix.LiveView.Socket
  alias Phoenix.Socket.Broadcast

  import CloudDbUi.AccountsFixtures

  @remember_me_cookie "_cloud_db_ui_web_user_remember_me"

  setup %{conn: conn} do
    conn_new =
      conn
      |> Map.replace!(
        :secret_key_base,
        CloudDbUiWeb.Endpoint.config(:secret_key_base)
      )
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn_new}
  end

  describe "log_in_user/3" do
    test "stores the user token in the session", %{conn: conn, user: user} do
      conn_new = UserAuth.log_in_user(conn, user)
      token = get_session(conn_new, :user_token)

      conn_new
      |> get_session(:live_socket_id)
      |> Kernel.==("users_sessions:#{Base.url_encode64(token)}")
      |> assert()

      assert(redirected_to(conn_new) == ~p"/")
      assert(Accounts.get_user_by_session_token(token))
    end

    test "clears everything previously stored in the session",
         %{conn: conn, user: user} do
      conn_new =
        conn
        |> put_session(:to_be_removed, "value")
        |> UserAuth.log_in_user(user)

      refute(get_session(conn_new, :to_be_removed))
    end

    test "redirects to the configured path", %{conn: conn, user: user} do
      conn_new =
        conn
        |> put_session(:user_return_to, "/hello")
        |> UserAuth.log_in_user(user)

      assert(redirected_to(conn_new) == "/hello")
    end

    test "writes a cookie if remember_me is configured",
         %{conn: conn, user: user} do
      conn_new =
        conn
        |> fetch_cookies()
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      %{value: signed_token, max_age: max_age} =
        conn_new.resp_cookies[@remember_me_cookie]

      token = get_session(conn_new, :user_token)

      assert(token == conn_new.cookies[@remember_me_cookie])
      assert(signed_token != token)
      assert(max_age == 5_184_000)
    end
  end

  describe "logout_user/1" do
    test "erases session and cookies", %{conn: conn, user: user} do
      user_token = Accounts.generate_user_session_token(user)

      conn_new =
        conn
        |> put_session(:user_token, user_token)
        |> put_req_cookie(@remember_me_cookie, user_token)
        |> fetch_cookies()
        |> UserAuth.log_out_user()

      refute(get_session(conn_new, :user_token))
      refute(conn_new.cookies[@remember_me_cookie])
      assert(conn_new.resp_cookies[@remember_me_cookie][:max_age] == 0)
      assert(redirected_to(conn_new) == ~p"/")
      refute(Accounts.get_user_by_session_token(user_token))
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "users_sessions:abcdef-token"

      CloudDbUiWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UserAuth.log_out_user()

      assert_receive(%Broadcast{event: "disconnect", topic: ^live_socket_id})
    end

    test "works even if a user is already logged out", %{conn: conn} do
      conn_new =
        conn
        |> fetch_cookies()
        |> UserAuth.log_out_user()

      refute(get_session(conn_new, :user_token))
      assert(conn_new.resp_cookies[@remember_me_cookie][:max_age] == 0)
      assert(redirected_to(conn_new) == ~p"/")
    end
  end

  describe "fetch_current_user/2" do
    test "authenticates user from session", %{conn: conn, user: user} do
      conn_new =
        conn
        |> put_session(:user_token, Accounts.generate_user_session_token(user))
        |> UserAuth.fetch_current_user()

      assert(conn_new.assigns.current_user.id == user.id)
    end

    test "authenticates user from cookies", %{conn: conn, user: user} do
      logged_in_conn =
        conn
        |> fetch_cookies()
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn_new =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> UserAuth.fetch_current_user()

      assert(conn_new.assigns.current_user.id == user.id)
      assert(get_session(conn_new, :user_token) == user_token)

      conn_new
      |> get_session(:live_socket_id)
      |> Kernel.==("users_sessions:#{Base.url_encode64(user_token)}")
      |> assert()
    end

    test "does not authenticate if data is missing",
         %{conn: conn, user: user} do
      Accounts.generate_user_session_token(user)

      conn_new = UserAuth.fetch_current_user(conn)

      refute(get_session(conn_new, :user_token))
      refute(conn_new.assigns.current_user)
    end
  end

  describe "on_mount :mount_current_user" do
    test "assigns current_user based on a valid user_token",
         %{conn: conn, user: user} do
      session =
        conn
        |> put_session(:user_token, Accounts.generate_user_session_token(user))
        |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %Socket{})

      assert(updated_socket.assigns.current_user.id == user.id)
    end

    test "assigns nil to current_user assign if no valid user_token",
         %{conn: conn} do
      session =
        conn
        |> put_session(:user_token, "invalid_token")
        |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:mount_current_user, %{}, session, %Socket{})

      assert(updated_socket.assigns.current_user == nil)
    end

    test "assigns nil to current_user assign if no user_token",
         %{conn: conn} do
      {:cont, updated_socket} =
        UserAuth.on_mount(
          :mount_current_user,
          %{},
          get_session(conn),
          %Socket{}
        )

      assert(updated_socket.assigns.current_user == nil)
    end
  end

  describe "on_mount :ensure_authenticated" do
    test "authenticates current_user based on a valid user_token",
         %{conn: conn, user: user} do
      session =
        conn
        |> put_session(:user_token, Accounts.generate_user_session_token(user))
        |> get_session()

      {:cont, updated_socket} =
        UserAuth.on_mount(:ensure_authenticated, %{}, session, %Socket{})

      assert(updated_socket.assigns.current_user.id == user.id)
    end

    test "redirects to the log-in page if no valid user_token",
         %{conn: conn} do
      session =
        conn
        |> put_session(:user_token, "invalid_token")
        |> get_session()

      {:halt, updated_socket} =
        UserAuth.on_mount(:ensure_authenticated, %{}, session, socket(%{}))

      assert(updated_socket.assigns.current_user == nil)
    end

    test "redirects to the log-in page if no user_token", %{conn: conn} do
      {:halt, updated_socket} =
        UserAuth.on_mount(
          :ensure_authenticated,
          %{},
          get_session(conn),
          socket(%{})
        )

      assert(updated_socket.assigns.current_user == nil)
    end
  end

  describe "on_mount :redirect_if_user_is_authenticated" do
    test "redirects if there is an authenticated user",
         %{conn: conn, user: user} do
      session =
        conn
        |> put_session(:user_token, Accounts.generate_user_session_token(user))
        |> get_session()

      result =
        UserAuth.on_mount(
          :redirect_if_user_is_authenticated,
          %{},
          session,
          %Socket{}
        )

      assert({:halt, _updated_socket} = result)
    end

    test "doesn't redirect if there is no authenticated user", %{conn: conn} do
      result =
        UserAuth.on_mount(
          :redirect_if_user_is_authenticated,
          %{},
          get_session(conn),
          %Socket{}
        )

      assert({:cont, _updated_socket} = result)
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "redirects if a user is authenticated", %{conn: conn, user: user} do
      conn_new =
        conn
        |> assign(:current_user, user)
        |> UserAuth.redirect_if_user_is_authenticated([])

      assert(conn_new.halted)
      assert(redirected_to(conn_new) == ~p"/")
    end

    test "does not redirect if a user is not authenticated", %{conn: conn} do
      conn_new = UserAuth.redirect_if_user_is_authenticated(conn, [])

      refute(conn_new.halted)
      refute(conn_new.status)
    end
  end

  describe "require_authenticated_user/2" do
    test "redirects if a user is not authenticated", %{conn: conn} do
      conn_new =
        conn
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert(conn_new.halted)
      assert(redirected_to(conn_new) == ~p"/users/log_in")

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("You must log in to access this page.")
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert(halted_conn.halted)
      assert(get_session(halted_conn, :user_return_to) == "/foo")

      halted_query_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert(halted_query_conn.halted)
      assert(get_session(halted_query_conn, :user_return_to) == "/foo?bar=baz")

      halted_post_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert(halted_post_conn.halted)
      refute(get_session(halted_post_conn, :user_return_to))
    end

    test "does not redirect if a user is authenticated", %{conn: conn, user: user} do
      conn_new =
        conn
        |> assign(:current_user, user)
        |> UserAuth.require_authenticated_user([])

      refute(conn_new.halted)
      refute(conn_new.status)
    end
  end

  @spec socket(%{atom() => any()}) :: %Socket{}
  defp socket(assigns) do
    %Socket{
      endpoint: CloudDbUiWeb.Endpoint,
      assigns: Enum.into(assigns, %{__changed__: %{}, flash: %{}})
    }
  end
end
