defmodule CloudDbUi.AccountsTest do
  use CloudDbUi.DataCase

  alias CloudDbUi.Orders
  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.{User, UserToken}
  alias Ecto.Changeset
  alias Flop.Meta

  import CloudDbUi.{AccountsFixtures, OrdersFixtures, ProductsFixtures}

  @invalid_attrs %{email: "bad", password: "¢", password_confirmation: "_"}

  @valid_attrs %{
    email: "user_a_b_c_d@userabcd.pl",
    email_confirmation: "user_a_b_c_d@userabcd.pl",
    password: "Test123.",
    password_confirmation: "Test123."
  }

  describe "list_users_with_order_count/0" do
    test "returns all users with order count" do
      user = user_fixture()

      order_fixture(%{user: user})
      order_fixture(%{user: user, paid: true})

      user_new =
        user
        |> Map.replace!(:orders, 2)
        |> Map.replace!(:paid_orders, 1)

      {:ok, {users, %Meta{}}} = Accounts.list_users_with_order_count()

      assert(users == [user_new])
    end
  end

  test "get_user_with_order_suborder_products!/1 returns a user w/ preloads" do
    prod = product_fixture()
    user = user_fixture()
    order = order_fixture(%{user: user})

    suborder =
      %{order: order, product: prod}
      |> suborder_fixture()
      |> Map.replace!(:product, prod)
      |> Map.replace!(:subtotal, nil)

    usr_new =
      user
      |> Map.replace!(:orders, [Map.replace!(order, :suborders, [suborder])])
      |> Map.replace!(:paid_orders, 0)

    assert(Accounts.get_user_with_order_suborder_products!(user.id) == usr_new)
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the e-mail does not exist" do
      refute(Accounts.get_user_by_email("unknown_98@example_12.com"))
    end

    test "returns the user if the e-mail exists" do
      %{id: id, email: e_mail} = user_fixture()

      assert(%User{id: ^id} = Accounts.get_user_by_email(e_mail))
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the e-mail does not exist" do
      refute(Accounts.get_user_by_email_and_password("abs3nt@b.c", "Test123."))
    end

    test "does not return the user if the password is not valid" do
      user_fixture()
      |> Map.fetch!(:email)
      |> Accounts.get_user_by_email_and_password("invalid")
      |> refute()
    end

    test "returns the user if an e-mail and a password are valid" do
      %{id: id, email: e_mail} = user_fixture()
      user = Accounts.get_user_by_email_and_password(e_mail, valid_password())

      assert(%User{id: ^id} = user)
    end
  end

  describe "get_user_with_order_count!/1" do
    test "raises if the ID is invalid" do
      assert_raise(Ecto.NoResultsError, fn ->
        Accounts.get_user_with_order_count!(-1)
      end)
    end

    test "returns a user with the given ID" do
      %User{id: id} = user_fixture()

      assert(%User{id: ^id} = Accounts.get_user_with_order_count!(id))
    end
  end

  describe "create_user/1" do
    test "creates a non-administrator user with a non-zero balance" do
      {:ok, %User{id: id}} =
        %{balance: 2}
        |> Enum.into(@valid_attrs)
        |> Accounts.create_user()

      assert(%User{id: ^id} = CloudDbUi.Repo.get!(User, id))
    end

    test "does not create an administrator with a non-zero balance" do
      errs =
        %{admin: true, balance: 2}
        |> Enum.into(@valid_attrs)
        |> Accounts.create_user()
        |> errors_on()

      assert(%{balance: ["can't be non-zero for an admin"]} = errs)
    end
  end

  describe "update_user/2" do
    test "updates a non-administrator user to have non-zero balance" do
      {:ok, %User{id: id}} =
        user_fixture()
        |> Accounts.update_user(%{balance: 2})

      assert(%User{id: ^id} = CloudDbUi.Repo.get!(User, id))
    end

    test "does not update an administrator to have non-zero balance" do
      errs =
        %{admin: true}
        |> user_fixture()
        |> Accounts.update_user(%{balance: 2})
        |> errors_on()

      assert(%{balance: ["can't be non-zero for an admin"]} = errs)
    end
  end

  describe "top_up_user_balance/2" do
    test "tops up the balance of a non-administrator user" do
      {:ok, %User{} = user_topped} =
        Accounts.top_up_user_balance(user_fixture(), %{top_up_amount: 5.01})

      assert(user_topped.balance == Decimal.new("5.01"))
      assert(CloudDbUi.Repo.get!(User, user_topped.id) == user_topped)
    end

    test "does not top up the balance of an administrator" do
      errs =
        %{admin: true}
        |> user_fixture()
        |> Accounts.top_up_user_balance(%{top_up_amount: 5.01})
        |> errors_on()

      assert(%{balance: ["can't be non-zero for an admin"]} = errs)
    end

    test "does not top up if the top up amount is too low" do
      user = user_fixture()

      errs =
        user
        |> Accounts.top_up_user_balance(%{top_up_amount: 4.99})
        |> errors_on()

      errs.top_up_amount
      |> hd()
      |> Kernel.=~("must be greater than or equal to #{user.top_up_amount}")
      |> assert()
    end

    test "does not top up if the top up amount is too high" do
      over_limit =
        User.top_up_amount_limit()
        |> Decimal.add("0.01")

      errs =
        user_fixture()
        |> Accounts.top_up_user_balance(%{top_up_amount: over_limit})
        |> errors_on()

      errs.top_up_amount
      |> hd()
      |> Kernel.=~("st be less than or equal to #{User.top_up_amount_limit()}")
      |> assert()
    end
  end

  describe "register_user/1" do
    test "requires an e-mail and a password to be set" do
      errs =
        Accounts.register_user()
        |> errors_on()

      assert(%{password: ["can't be blank"], email: ["can't be blank"]} = errs)
    end

    test "validates an e-mail and a password when given" do
      %{email: errs_email, password: errs_pw} =
        @invalid_attrs
        |> Accounts.register_user()
        |> errors_on()

      assert(errs_email == ["invalid e-mail format"])
      assert("at least one digit, space or punctuation character" in errs_pw)
      assert("at least one upper-case character" in errs_pw)
      assert("at least one lower-case character" in errs_pw)
      assert("should be at least 8 character(s)" in errs_pw)
      assert(length(errs_pw) == 4)
    end

    test "validates value length for an e-mail and for a password" do
      too_long = String.duplicate("i", 161)

      errs =
        %{email: too_long, password: too_long}
        |> Accounts.register_user()
        |> errors_on()

      assert("should be at most 160 character(s)" in errs.email)
      assert("should be at most 72 character(s)" in errs.password)
    end

    test "validates e-mail uniqueness" do
      %{email: taken} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: taken})

      assert("has already been taken" in errors_on(changeset).email)

      # Check that e-mail case is ignored.
      {:error, set} = Accounts.register_user(%{email: String.upcase(taken)})

      assert("has already been taken" in errors_on(set).email)
    end

    test "registers users with a hashed password" do
      email = unique_email()
      {:ok, user} =
        [email: email]
        |> Enum.into(valid_user_attributes())
        |> Accounts.register_user()

      assert(user.email == email)
      assert(is_binary(user.hashed_password))
      assert(user.confirmed_at == nil)
      assert(user.password == nil)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      changeset = Accounts.change_user_registration(%User{})

      assert(%Changeset{} = changeset)
      assert(changeset.required == [:password, :email])
    end

    test "allows fields to be set" do
      attrs = valid_user_attributes()
      changeset = Accounts.change_user_registration(%User{}, attrs)

      assert(changeset.valid?)
      assert(get_change(changeset, :email) == attrs.email)
      assert(get_change(changeset, :password) == attrs.password)
      assert(get_change(changeset, :hashed_password) == nil)
    end
  end

  describe "delete_user/1" do
    test "deletes a non-admin user with zero balance and no paid orders" do
      user =
        user_fixture()
        |> Map.replace!(:paid_orders, 0)

      unpaid = order_fixture(%{user: user})
      suborder = suborder_fixture(%{order: unpaid})
      {:ok, %User{}} = Accounts.delete_user(user)

      assert_raise(Ecto.NoResultsError, fn ->
        Accounts.get_user_with_order_count!(user.id)
      end)

      assert_raise(Ecto.NoResultsError, fn ->
        Orders.get_order_with_suborder_ids!(unpaid.id)
      end)

      assert_raise(Ecto.NoResultsError, fn ->
        Orders.get_suborder!(suborder.id)
      end)
    end

    test "does not delete a user with non-zero balance" do
      user =
        %{balance: 0.01}
        |> user_fixture()
        |> Map.replace!(:orders, 0)
        |> Map.replace!(:paid_orders, 0)

      {:error, %Changeset{} = set} = Accounts.delete_user(user)

      assert(errors_on(set).balance == ["the user has positive balance"])
      assert(Accounts.get_user_with_order_count!(user.id) == user)
    end

    test "does not delete a user that has a paid order" do
      user =
        user_fixture()
        |> Map.replace!(:orders, 1)
        |> Map.replace!(:paid_orders, 1)

      order = order_fixture(%{user: user})

      suborder_fixture(%{order: order})
      set_as_paid(order, user)

      {:error, %Changeset{} = set} =
        user.id
        |> Accounts.get_user_with_order_count!()
        |> Accounts.delete_user()

      assert(errors_on(set).paid_orders == ["the user has a paid order"])
      assert(Accounts.get_user_with_order_count!(user.id) == user)
    end

    test "does not delete an admin" do
      user =
        %{admin: true}
        |> user_fixture()
        |> Map.replace!(:orders, 0)
        |> Map.replace!(:paid_orders, 0)

      {:error, %Changeset{} = set} = Accounts.delete_user(user)

      assert(errors_on(set).admin == ["the user is an administrator"])
      assert(Accounts.get_user_with_order_count!(user.id) == user)
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      changeset = Accounts.change_user_email(%User{})

      assert(%Changeset{} = changeset)
      assert(changeset.required == [:email])
    end
  end

  describe "apply_user_email/3" do
    setup do: %{user: user_fixture()}

    test "requires the e-mail address to change", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_password(), %{})

      assert(%{email: ["did not change"]} = errors_on(changeset))
    end

    test "validates the e-mail address", %{user: user} do
      {:error, set} =
        Accounts.apply_user_email(user, valid_password(), %{email: "invalid"})

      assert(%{email: ["invalid e-mail format"]} = errors_on(set))
    end

    test "validates the maximum length of the e-mail address", %{user: user} do
      too_long = String.duplicate("i", 161)

      {:error, set} =
        Accounts.apply_user_email(user, valid_password(), %{email: too_long})

      assert("should be at most 160 character(s)" in errors_on(set).email)
    end

    test "validates e-mail uniqueness", %{user: user} do
      %{email: e_mail} = user_fixture()

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_password(), %{email: e_mail})

      assert("has already been taken" in errors_on(changeset).email)
    end

    test "validates the current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_email()})

      assert(%{current_password: ["is not valid"]} = errors_on(changeset))
    end

    test "applies the e-mail address without persisting it", %{user: user} do
      e_mail = unique_email()

      {:ok, user} =
        Accounts.apply_user_email(user, valid_password(), %{email: e_mail})

      assert(user.email == e_mail)
      assert(Accounts.get_user_with_order_count!(user.id).email != e_mail)
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do: %{user: user_fixture()}

    test "sends a token through a notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(
            user,
            "current@example.com",
            url
          )
        end)

      decoded = Base.url_decode64!(token, [padding: false])

      user_token =
        Repo.get_by!(UserToken, [token: :crypto.hash(:sha256, decoded)])

      assert(user_token.user_id == user.id)
      assert(user_token.sent_to == user.email)
      assert(user_token.context == "change:current@example.com")
    end
  end

  describe "update_user_email/2" do
    setup do
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

      %{user: user, token: token, email: email}
    end

    test "updates the e-mail address with a valid token",
         %{user: user, token: token, email: email} do
      assert(Accounts.update_user_email(user, token) == :ok)

      changed_user = Repo.get!(User, user.id)

      assert(changed_user.email != user.email)
      assert(changed_user.email == email)
      assert(changed_user.confirmed_at)
      assert(changed_user.confirmed_at != user.confirmed_at)
      refute(Repo.get_by(UserToken, [user_id: user.id]))
    end

    test "does not update e-mail with an invalid token", %{user: user} do
      assert(Accounts.update_user_email(user, "oops") == :error)
      assert(Repo.get!(User, user.id).email == user.email)
      assert(Repo.get_by(UserToken, [user_id: user.id]))
    end

    test "does not update e-mail if the user's e-mail changed",
         %{user: user, token: token} do
      %{user | email: "current@example.com"}
      |> Accounts.update_user_email(token)
      |> Kernel.==(:error)
      |> assert()

      assert(Repo.get!(User, user.id).email == user.email)
      assert(Repo.get_by(UserToken, [user_id: user.id]))
    end

    test "does not update the e-mail if the token expired",
         %{user: user, token: token} do
      {1, nil} =
        Repo.update_all(
          UserToken,
          [set: [inserted_at: ~N[2020-01-01 00:00:00]]]
        )

      assert(Accounts.update_user_email(user, token) == :error)
      assert(Repo.get!(User, user.id).email == user.email)
      assert(Repo.get_by(UserToken, [user_id: user.id]))
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      changeset = Accounts.change_user_password(%User{})

      assert(%Changeset{} = changeset)
      assert(changeset.required == [:password])
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{"password" => "New.Valid1"})

      assert(changeset.valid?)
      assert(get_change(changeset, :password) == "New.Valid1")
      assert(get_change(changeset, :hashed_password) == nil)
    end
  end

  describe "update_user_password/3" do
    setup do: %{user: user_fixture()}

    test "validates password", %{user: user} do
      %{password: errs_pw, password_confirmation: errs_confirmation} =
        user
        |> Accounts.update_user_password(valid_password(), @invalid_attrs)
        |> errors_on()

      assert("at least one digit, space or punctuation character" in errs_pw)
      assert("at least one upper-case character" in errs_pw)
      assert("at least one lower-case character" in errs_pw)
      assert("should be at least 8 character(s)" in errs_pw)
      assert(length(errs_pw) == 4)
      assert(errs_confirmation == ["does not match password"])
    end

    test "validates maximum password length", %{user: user} do
      {:error, set} =
        Accounts.update_user_password(
          user,
          valid_password(),
          %{password: String.duplicate("i", 73)}
        )

      assert("should be at most 72 character(s)" in errors_on(set).password)
    end

    test "validates the current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(
          user,
          "invalid",
          %{password: valid_password()}
        )

      assert(errors_on(changeset).current_password == ["is not valid"])
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(
          user,
          valid_password(),
          %{password: "New.Valid1"}
        )

      assert(user.password == nil)
      assert(Accounts.get_user_by_email_and_password(user.email, "New.Valid1"))
    end

    test "deletes all tokens for the given user", %{user: user} do
      Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(
          user,
          valid_password(),
          %{password: "New.Valid1"}
        )

      refute(Repo.get_by(UserToken, [user_id: user.id]))
    end
  end

  describe "generate_user_session_token/1" do
    setup do: %{user: user_fixture()}

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      user_token = Repo.get_by(UserToken, [token: token])

      assert(user_token.context == "session")

      # Creating the same token for an other user should fail.
      assert_raise(Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end)
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()

      %{user: user, token: Accounts.generate_user_session_token(user)}
    end

    test "returns a user by token", %{user: user, token: token} do
      session_user = Accounts.get_user_by_session_token(token)

      assert(session_user.id == user.id)
    end

    test "does not return a user for an invalid token" do
      refute(Accounts.get_user_by_session_token("oops"))
    end

    test "does not return a user for an expired token", %{token: token} do
      {1, nil} =
        Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      refute(Accounts.get_user_by_session_token(token))
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      token =
        user_fixture()
        |> Accounts.generate_user_session_token()

      assert(Accounts.delete_user_session_token(token) == :ok)
      refute(Accounts.get_user_by_session_token(token))
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do: %{user: user_fixture()}

    test "sends a token through a notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      decoded = Base.url_decode64!(token, padding: false)

      user_token =
        Repo.get_by!(UserToken, [token: :crypto.hash(:sha256, decoded)])

      assert(user_token.user_id == user.id)
      assert(user_token.sent_to == user.email)
      assert(user_token.context == "confirm")
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the e-mail address with a valid token",
         %{user: user, token: token} do
      {:ok, confirmed_user} = Accounts.confirm_user(token)

      assert(confirmed_user.confirmed_at)
      assert(confirmed_user.confirmed_at != user.confirmed_at)
      assert(Repo.get!(User, user.id).confirmed_at)
      refute(Repo.get_by(UserToken, [user_id: user.id]))
    end

    test "does not confirm the e-mail with an invalid token", %{user: user} do
      assert(Accounts.confirm_user("oops") == :error)
      refute(Repo.get!(User, user.id).confirmed_at)
      assert(Repo.get_by(UserToken, [user_id: user.id]))
    end

    test "does not confirm the e-mail if the token expired",
         %{user: user, token: token} do
      {1, nil} =
        Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert(Accounts.confirm_user(token) == :error)
      refute(Repo.get!(User, user.id).confirmed_at)
      assert(Repo.get_by(UserToken, [user_id: user.id]))
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do: %{user: user_fixture()}

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      decoded = Base.url_decode64!(token, padding: false)

      user_token =
        Repo.get_by!(UserToken, [token: :crypto.hash(:sha256, decoded)])

      assert(user_token.user_id == user.id)
      assert(user_token.sent_to == user.email)
      assert(user_token.context == "reset_password")
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns a user with a valid token",
         %{user: %{id: id}, token: token} do
      assert(%User{id: ^id} = Accounts.get_user_by_reset_password_token(token))
      assert(Repo.get_by(UserToken, [user_id: id]))
    end

    test "does not return a user with an invalid token", %{user: user} do
      refute(Accounts.get_user_by_reset_password_token("oops"))
      assert(Repo.get_by(UserToken, [user_id: user.id]))
    end

    test "does not return a user if the token expired",
         %{user: user, token: token} do
      {1, nil} =
        Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      refute(Accounts.get_user_by_reset_password_token(token))
      assert(Repo.get_by(UserToken, [user_id: user.id]))
    end
  end

  describe "reset_user_password/2" do
    setup do: %{user: user_fixture()}

    test "validates a password", %{user: user} do
      %{password: errs_pw, password_confirmation: errs_confirmation} =
        user
        |> Accounts.reset_user_password(@invalid_attrs)
        |> errors_on()

      assert("at least one digit, space or punctuation character" in errs_pw)
      assert("at least one upper-case character" in errs_pw)
      assert("at least one lower-case character" in errs_pw)
      assert("should be at least 8 character(s)" in errs_pw)
      assert(length(errs_pw) == 4)
      assert(errs_confirmation == ["does not match password"])
    end

    test "validates the maximum length for a password", %{user: user} do
      {:error, set} =
        Accounts.reset_user_password(
          user,
          %{password: String.duplicate("i", 73)}
        )

      assert("should be at most 72 character(s)" in errors_on(set).password)
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} =
        Accounts.reset_user_password(user, %{password: "New.Valid1"})

      assert(updated_user.password == nil)
      assert(Accounts.get_user_by_email_and_password(user.email, "New.Valid1"))
    end

    test "deletes all tokens for the given user", %{user: user} do
      Accounts.generate_user_session_token(user)

      {:ok, _} = Accounts.reset_user_password(user, %{password: "New.Valid1"})

      refute(Repo.get_by(UserToken, [user_id: user.id]))
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute(inspect(%User{password: "123456"}) =~ "password: \"123456\"")
    end
  end
end
