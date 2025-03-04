defmodule CloudDbUiWeb.TopUpLiveTest do
  use CloudDbUiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CloudDbUi.Accounts.User
  alias Phoenix.LiveViewTest.View

  @type redirect_error() :: CloudDbUi.Type.redirect_error()

  describe "A not-logged-in guest" do
    test "gets redirected away", %{conn: conn} do
      assert_redirect_to_log_in_page(conn, ~p"/top_up")
    end
  end

  describe "An admin" do
    setup [:register_and_log_in_admin]

    test "gets redirected away", %{conn: conn} do
      assert_redirect_to_main_page(
        conn,
        ~p"/top_up",
        "This is a page for non-administrator users."
      )
    end
  end

  describe "A user" do
    setup [:register_and_log_in_user]

    test "can top up balance with a valid amount", %{conn: conn, user: user} do
      {:ok, top_up_live, _html} = live(conn, ~p"/top_up")

      assert_balance_after_topping_up_changes(top_up_live, user)

      top_up(top_up_live, 5)

      assert(page_title(top_up_live) =~ "Top up")
      assert(has_header?(top_up_live, "Top up your balance"))
      assert(has_flash?(top_up_live, :info, "Topped up successfully."))
    end

    test "cannot top up with an invalid amount", %{conn: conn, user: user} do
      {:ok, top_up_live, _html} = live(conn, ~p"/top_up")

      assert_form_errors(top_up_live, user)
    end
  end

  @spec assert_form_errors(%View{}, %User{}) :: boolean()
  defp assert_form_errors(%View{} = live, user) do
    assert(form_errors(live, "#top-up-form") == [])
    assert_decimal_field_errors(live, "#top-up-form", :user, :top_up_amount)

    change_amount(live, "4.99")

    live
    |> has_form_error?("#top-up-form", :top_up_amount, "be greater than or eq")
    |> assert()

    change_amount(live, "-0.01")

    live
    |> has_form_error?("#top-up-form", :top_up_amount, "be greater than or eq")
    |> assert()

    change_amount(live, Decimal.add(User.top_up_amount_limit(), "0.01"))

    live
    |> has_form_error?(
      "#top-up-form",
      :top_up_amount,
      "be less than or equal to #{User.top_up_amount_limit()}"
    )
    |> assert()

    top_up_to_limit(live)

    change_amount(live, user.top_up_amount)

    live
    |> has_form_error?(
      "#top-up-form",
      :top_up_amount,
      "(PLN #{User.balance_limit}) by PLN #{user.top_up_amount}"
    )
    |> assert()
  end

  # Should return a rendered `#top-up-form`.
  @spec change_amount(%View{}, any()) :: String.t() | redirect_error()
  defp change_amount(%View{} = top_up_live, amount) do
    change_form(top_up_live, %{top_up_amount: amount})
  end

  @spec change_form(%View{}, %{atom() => any()}) ::
          String.t() | redirect_error()
  def change_form(%View{} = top_up_live, user_data) do
    change(top_up_live, "#top-up-form", %{user: user_data})
  end

  @spec top_up(%View{}, any()) :: String.t() | redirect_error()
  defp top_up(%View{} = top_up_live, amount) do
    submit(top_up_live, "#top-up-form", %{user: %{top_up_amount: amount}})
  end

  @spec top_up_to_limit(%View{}) :: String.t() | redirect_error()
  defp top_up_to_limit(%View{} = live) do
    change_amount(live, User.top_up_amount_limit())

    live
    |> form_errors("#top-up-form", :top_up_amount)
    |> Enum.find(&(&1 =~ "will exceed balance limit (PLN"))
    |> case do
      nil ->
        top_up(live, User.top_up_amount_limit())
        top_up_to_limit(live)

      error_exceeded ->
        [excess] = Regex.run(~r/(?<=by PLN )\d+(?:\.\d+)/, error_exceeded)

        top_up(live, Decimal.sub(User.top_up_amount_limit(), excess))
    end
  end

  # Check that "Balance after topping up" gets recalculated.
  @spec assert_balance_after_topping_up_changes(%View{}, %User{}) :: boolean()
  defp assert_balance_after_topping_up_changes(%View{} = live_view, user) do
    amount_new =
      live_view
      |> input_value(:top_up_amount)
      |> changed_top_up_amount(user)

    live_view
    |> change_amount(amount_new)
    |> assert_match("PLN #{Decimal.add(user.balance, amount_new)}")
  end

  # Returns a new top up amount converted to a string.
  @spec changed_top_up_amount(%Decimal{} | String.t(), %User{}) :: String.t()
  defp changed_top_up_amount(amount, user) do
    case Decimal.compare(amount, User.top_up_amount_limit()) do
      :lt -> Decimal.add(amount, "0.01")
      _eq_or_gt -> Decimal.add(user.top_up_amount, "0.01")
    end
    |> Decimal.to_string(:normal)
  end
end
