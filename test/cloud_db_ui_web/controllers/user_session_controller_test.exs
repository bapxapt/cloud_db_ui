defmodule CloudDbUiWeb.UserSessionControllerTest do
  use CloudDbUiWeb.ConnCase, async: true

  import CloudDbUi.AccountsFixtures

  @type post_body() :: %{atom() => %{atom() => String.t()} | String.t()}

  setup do: %{user: user_fixture()}

  describe "POST /log_in" do
    test "logs the user in", %{conn: conn, user: user} do
      conn_posted = post_to_log_in(conn, user.email)

      assert(get_session(conn_posted, :user_token))
      assert(redirected_to(conn_posted) == ~p"/")

      # Now do a logged-in request and assert on the menu.
      conn_main = get(conn_posted, ~p"/")

      assert(redirected_to(conn_main) == ~p"/products")

      response =
        conn_main
        |> get(~p"/products")
        |> html_response(200)

      assert(response =~ user.email)
      assert(response =~ ~p"/settings")
      assert(response =~ ~p"/log_out")
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn_new = post_to_log_in(conn, user.email, nil, valid_password(), true)

      assert(conn_new.resp_cookies["_cloud_db_ui_web_user_remember_me"])
      assert(redirected_to(conn_new) == ~p"/")
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn_new =
        conn
        |> init_test_session([user_return_to: "/foo/bar"])
        |> post_to_log_in(user.email)

      assert(redirected_to(conn_new) == "/foo/bar")

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("Welcome back!")
    end

    test "log-in following registration", %{conn: conn, user: user} do
      conn_new = post_to_log_in(conn, user.email, "registered")

      assert(redirected_to(conn_new) == ~p"/")

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("Account created successfully")
    end

    test "log-in following a password update", %{conn: conn, user: user} do
      conn_new = post_to_log_in(conn, user.email, "password_updated")

      assert(redirected_to(conn_new) == ~p"/settings")

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("Password updated successfully")
    end

    test "redirects to the log-in page with invalid credentials",
         %{conn: conn} do
      conn_new = post_to_log_in(conn, "invalid@email.com", "invalid_password")

      assert(redirected_to(conn_new) == ~p"/log_in")

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("Invalid e-mail or password.")
    end
  end

  describe "DELETE /log_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn_new =
        conn
        |> log_in_user(user)
        |> delete(~p"/log_out")

      assert(redirected_to(conn_new) == ~p"/")
      refute(get_session(conn_new, :user_token))

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("Logged out successfully.")
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn_new = delete(conn, ~p"/log_out")

      assert(redirected_to(conn_new) == ~p"/")
      refute(get_session(conn_new, :user_token))

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("You are not logged in.")
    end
  end

  @spec post_to_log_in(
          %Plug.Conn{},
          String.t(),
          String.t() | nil,
          String.t(),
          String.t() | boolean() | nil
        ) :: %Plug.Conn{}
  def post_to_log_in(
        %Plug.Conn{} = conn,
        e_mail,
        action \\ nil,
        password \\ valid_password(),
        remember_me \\ nil
      ) do
    post_body =
      %{user: %{email: e_mail, password: password}}
      |> maybe_put_action(action)
      |> maybe_put_remember_me(remember_me)

    post(conn, ~p"/log_in", post_body)
  end

  @spec maybe_put_action(post_body(), String.t() | nil) :: post_body()
  defp maybe_put_action(post_body, nil), do: post_body

  defp maybe_put_action(post_body, action) when is_binary(action) do
    Map.put_new(post_body, :_action, action)
  end

  @spec maybe_put_remember_me(post_body(), String.t() | boolean() | nil) ::
          post_body()
  defp maybe_put_remember_me(post_body, nil), do: post_body

  defp maybe_put_remember_me(post_body, state) do
    update_in(
      post_body,
      [:user],
      &Map.put_new(&1, :remember_me, String.downcase("#{state}"))
    )
  end
end
