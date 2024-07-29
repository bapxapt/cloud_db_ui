defmodule CloudDbUiWeb.TopUpLiveTest do
  use CloudDbUiWeb.ConnCase

  alias CloudDbUi.Accounts.User
  alias Phoenix.LiveViewTest.View

  import Phoenix.LiveViewTest

  describe "A not-logged-in guest" do
    test "gets redirected away", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/top_up")

      assert(path == ~p"/users/log_in")
      assert(flash["error"] =~ "You must log in")
    end
  end

  describe "An admin" do
    setup [:register_and_log_in_admin]

    test "gets redirected away", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/top_up")

      assert(path == ~p"/")
      assert(flash["error"] =~ "This is a page for non-administrator")
    end
  end

  describe "A user" do
    setup [:register_and_log_in_user]

    test "can top up balance with a valid amount", %{conn: conn, user: user} do
      {:ok, top_up_live, html} = live(conn, ~p"/top_up")

      assert_balance_after_topping_up_changes(top_up_live, user)

      top_up(top_up_live, 5)

      assert(html =~ "Top up your balance")
      assert(has_flash?(top_up_live, :info, "Topped up successfully."))
    end

    test "cannot top up with an invalid amount", %{conn: conn, user: user} do
      {:ok, top_up_live, _html} = live(conn, ~p"/top_up")

      assert_form_errors(top_up_live, user)
    end
  end

  @spec assert_form_errors(%View{}, %User{}) :: boolean()
  defp assert_form_errors(%View{} = live, user) do
    assert(change_amount(live, nil) =~ "can&#39;t be blank")
    assert(change_amount(live, "4.99") =~ "must be greater than or equal")
    assert(change_amount(live, "-0.01") =~ "must be greater than or equal")
    assert(change_amount(live, "1e2") =~ "invalid format")

    live
    |> change_amount(Decimal.add(User.top_up_amount_limit(), "0.01"))
    |> assert_match("be less than or equal to #{User.top_up_amount_limit()}")

    top_up_to_limit(live)

    live
    |> change_amount(user.top_up_amount)
    |> assert_match("(PLN #{User.balance_limit}) by PLN #{user.top_up_amount}")
  end

  # Check that "Balance after topping up" gets recalculated.
  @spec assert_balance_after_topping_up_changes(%View{}, %User{}) :: boolean()
  defp assert_balance_after_topping_up_changes(%View{} = live_view, user) do
    amount = input_value(live_view, "#user_top_up_amount")

    amount_new =
      case Decimal.compare(amount, User.top_up_amount_limit()) do
        :lt -> Decimal.add(amount, "0.01")
        _eq_or_gt -> Decimal.sub(amount, "0.01")
      end
      |> Decimal.to_string(:normal)

      live_view
    |> change_amount(amount_new)
    |> assert_match("PLN #{Decimal.add(user.balance, amount_new)}")
  end

  # Returns a rendered form.
  @spec change_amount(%View{}, any()) :: String.t()
  defp change_amount(%View{} = top_up_live, amount) do
    change(top_up_live, "#top-up-form", %{user: %{top_up_amount: amount}})
  end

  @spec top_up(%View{}, any()) :: String.t()
  defp top_up(%View{} = top_up_live, amount) do
    submit(top_up_live, "#top-up-form", %{user: %{top_up_amount: amount}})
  end

  @spec top_up_to_limit(%View{}) :: String.t()
  defp top_up_to_limit(%View{} = live) do
    if change_amount(live, User.top_up_amount_limit()) =~ "will exceed" do
      [excess] =
        Regex.run(~r/(?<=by PLN )\d+\.?\d*/, render(live, "p", "will exceed"))

      top_up(live, Decimal.sub(User.top_up_amount_limit(), excess))
    else
      top_up(live, User.top_up_amount_limit())
      top_up_to_limit(live)
    end
  end
end
