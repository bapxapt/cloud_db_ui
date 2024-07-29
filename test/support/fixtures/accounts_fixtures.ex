defmodule CloudDbUi.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CloudDbUi.Accounts` context.
  """

  def unique_username(), do: "user_#{System.unique_integer()}"

  def unique_email(), do: unique_username() <> "@example.com"

  def valid_password(), do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_email(),
      password: valid_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> CloudDbUi.Accounts.create_user()

    user
  end

  def admin_fixture(attrs \\ %{}) do
    attrs
    |> Map.put(:admin, true)
    |> user_fixture()
  end

  def user_inactive_fixture(attrs \\ %{}) do
    attrs
    |> Map.put(:active, false)
    |> user_fixture()
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
