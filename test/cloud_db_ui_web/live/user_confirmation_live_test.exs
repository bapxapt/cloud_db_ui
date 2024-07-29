defmodule CloudDbUiWeb.UserConfirmationLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  alias CloudDbUi.Accounts
  alias CloudDbUi.Repo

  setup do
    %{user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/some-token")

      assert(has_element?(lv, "button", "Confirm my account"))
    end

    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("User confirmed successfully")

      assert(Accounts.get_user_with_order_count!(user.id).confirmed_at)
      refute(get_session(conn, :user_token))
      assert(Repo.all(Accounts.UserToken) == [])

      # When not logged in.
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("User confirmation link is invalid or it has expired")

      # When logged in.
      conn =
        build_conn()
        |> log_in_user(user)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("User has already been confirmed.")
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:error)
      |> assert_match("User confirmation link is invalid or it has expired")

      refute(Accounts.get_user_with_order_count!(user.id).confirmed_at)
    end
  end
end
