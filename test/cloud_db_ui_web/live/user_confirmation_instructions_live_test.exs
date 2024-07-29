defmodule CloudDbUiWeb.UserConfirmationInstructionsLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  alias CloudDbUi.Accounts
  alias CloudDbUi.Repo

  setup do
    %{user: user_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      assert(has_element?(lv, "button", "Resend confirmation instructions"))
    end

    test "sends a new confirmation token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      {:ok, conn} =
        lv
        |> form("#resend-confirmation-form", user: %{email: " " <> user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("If your e-mail is in our system")

      token = Repo.get_by!(Accounts.UserToken, [user_id: user.id])

      assert(token.context == "confirm")
    end

    test "does not send confirmation token if a user is confirmed",
         %{conn: conn, user: user} do
      Repo.update!(Accounts.User.confirmation_changeset(user))

      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      {:ok, conn} =
        lv
        |> form("#resend-confirmation-form", user: %{email: " " <> user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("If your e-mail is in our system")

      refute(Repo.get_by(Accounts.UserToken, [user_id: user.id]))
    end

    test "does not send confirmation token if email is invalid",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm")

      {:ok, conn} =
        lv
        |> form(
          "#resend-confirmation-form",
          %{user: %{email: "unknown@example.com"}}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      conn.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("If your e-mail is in our system")

      assert(Repo.all(Accounts.UserToken) == [])
    end
  end
end
