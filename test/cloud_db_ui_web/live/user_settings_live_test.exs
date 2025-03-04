defmodule CloudDbUiWeb.UserSettingsLiveTest do
  use CloudDbUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import CloudDbUi.AccountsFixtures

  alias CloudDbUi.Accounts
  alias Phoenix.LiveViewTest.{View, Element}

  @type redirect_error() :: CloudDbUi.Type.redirect_error()

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/settings")

      assert(has_element?(lv, "button", "Change e-mail"))
      assert(has_element?(lv, "button", "Change password"))
    end

    test "redirects if the user is not logged in", %{conn: conn} do
      assert_redirect_to_log_in_page(conn, ~p"/settings")
    end
  end

  describe "update the email form" do
    setup [:register_and_log_in_user]

    test "updates the email", %{conn: conn, password: pass, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/settings")

      email_new =
        unique_email()
        |> String.upcase()

      rendered =
        submit(
          lv,
          "#email-form",
          %{current_password: pass, user: %{email: "    " <> email_new}}
        )

      assert(rendered =~ "A link to confirm your email change has been sent")
      assert(Accounts.get_user_by_email(user.email))
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings")

      assert_form_email_errors(lv, "#email-form")
      assert_user_email_label_change(lv, "#email-form")
    end

    test "renders errors with invalid data (phx-submit)",
         %{conn: conn, user: user} do
      taken = user_fixture().email
      {:ok, lv, _html} = live(conn, ~p"/settings")

      submit_email_form(
        lv,
        %{email: "  " <> String.upcase(user.email) <> "   "},
        "invalid"
      )

      assert(user.email != String.upcase(user.email))
      assert(has_form_error?(lv, "#email-form", :email, "did not change"))
      refute(has_form_error?(lv, "#email-form", "is not valid"))

      change(
        lv,
        "#email-form",
        %{current_password: "invalid", user: %{email: " " <> taken <> "  "}}
      )

      submit(lv, "#email-form")

      assert(has_form_error?(lv, "#email-form", :email, "already been taken"))
      refute(has_form_error?(lv, "#email-form", "is not valid"))

      change(
        lv,
        "#email-form",
        %{current_password: "invalid", user: %{email: " u" <> taken <> "  "}}
      )

      submit(lv, "#email-form")

      assert(has_form_error?(lv, "#email-form", "is not valid"))
    end
  end

  describe "update the password form" do
    setup [:register_and_log_in_user]

    test "updates the password", %{conn: conn, user: user, password: pw_old} do
      pw = valid_password() <> "!"
      {:ok, lv, _html} = live(conn, ~p"/settings")

      form =
        password_form(
          lv,
          %{email: user.email, password: pw, password_confirmation: pw},
          pw_old
        )

      render_submit(form)

      conn_new = follow_trigger_action(form, conn)
      token_new = get_session(conn_new, :user_token)

      assert(redirected_to(conn_new) == ~p"/settings")
      assert(token_new != get_session(conn, :user_token))

      conn_new.assigns.flash
      |> Phoenix.Flash.get(:info)
      |> assert_match("Password updated successfully")

      assert(Accounts.get_user_by_email_and_password(user.email, pw))
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings")

      assert_form_password_errors(lv, "#password-form")
      assert_user_password_label_change(lv, "#password-form")
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings")

      submit_password_form(
        lv,
        %{password: "¢", password_confirmation: "not matching"},
        "invalid"
      )

      lv
      |> has_form_error?(
        "#password-form",
        :password,
        "at least one digit, space or punctuation character")
      |> assert()

      assert(has_form_error?(lv, "#password-form", :password, "one upper-cas"))
      assert(has_form_error?(lv, "#password-form", :password, "one lower-cas"))
      refute(has_form_error?(lv, "#password-form", "is not valid"))

      lv
      |> has_form_error?(
        "#password-form",
        :password_confirmation,
        "does not match password")
      |> assert()

      change_password_form(
        lv,
        %{password: "Test123.!", password_confirmation: "Test123.!"},
        "invalid"
      )

      submit(lv, "#password-form")

      assert(has_form_error?(lv, "#password-form", "is not valid"))
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(
            %{user | email: email},
            user.email,
            url
          )
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates a user's e-mail address once",
         %{conn: conn, user: user, token: token, email: email} do
      {:ok, live_view, _html} =
        conn
        |> live(~p"/settings/confirm_email/#{token}")
        |> follow_redirect(conn, ~p"/settings")

      assert(has_flash?(live_view, :info, "E-mail changed successfully."))
      refute(Accounts.get_user_by_email(user.email))
      assert(Accounts.get_user_by_email(email))

      # Use the same confirmation token again.
      {:ok, live, _html} =
        conn
        |> live(~p"/settings/confirm_email/#{token}")
        |> follow_redirect(conn, ~p"/settings")

      assert(has_flash?(live, "E-mail change link is invalid or it has expir"))
      refute(Accounts.get_user_by_email(user.email))
      assert(Accounts.get_user_by_email(email))
    end

    test "does not update the e-mail address with an invalid token",
         %{conn: conn, user: user} do
      {:ok, live, _html} =
        conn
        |> live(~p"/settings/confirm_email/BAD_TOKEN")
        |> follow_redirect(conn, ~p"/settings")

      assert(has_flash?(live, "E-mail change link is invalid or it has expir"))
      assert(Accounts.get_user_by_email(user.email))
    end

    test "redirects if a user is not logged in", %{token: token} do
      build_conn()
      |> assert_redirect_to_log_in_page(~p"/settings/confirm_email/#{token}")
    end
  end

  # Should return a rendered `#email-form`.
  @spec submit_email_form(%View{}, %{atom() => any()}, String.t()) ::
          String.t() | redirect_error()
  defp submit_email_form(%View{} = live, user_data, pass) do
    submit(live, "#email-form", %{user: user_data, current_password: pass})
  end

  # Should return a rendered `#password-form`.
  @spec change_password_form(%View{}, %{atom() => any()}, String.t()) ::
          String.t() | redirect_error()
  defp change_password_form(%View{} = live, user_data, pass) do
    change(live, "#password-form", %{user: user_data, current_password: pass})
  end

  @spec submit_password_form(%View{}, %{atom() => any()}, String.t()) ::
          String.t() | redirect_error()
  defp submit_password_form(%View{} = live, user_data, pass) do
    submit(live, "#password-form", %{user: user_data, current_password: pass})
  end

  @spec password_form(%View{}, %{atom() => any()}, String.t()) :: %Element{}
  defp password_form(%View{} = live, user_data, pass) do
    form(live, "#password-form", %{user: user_data, current_password: pass})
  end
end
