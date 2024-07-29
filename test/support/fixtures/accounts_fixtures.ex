defmodule CloudDbUi.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CloudDbUi.Accounts` context.
  """

  alias CloudDbUi.Accounts.User

  @type attrs() :: CloudDbUi.Type.attrs()

  @spec unique_username() :: String.t()
  def unique_username(), do: "user_#{System.unique_integer()}"

  @spec unique_email() :: String.t()
  def unique_email(), do: unique_username() <> "@example.com"

  @spec valid_password() :: String.t()
  def valid_password(), do: "Hello world!"

  @spec valid_user_attributes(attrs()) :: attrs()
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(
      attrs,
      %{email: unique_email(), password: valid_password()}
    )
  end

  @doc """
  Generate a user.
  """
  @spec user_fixture(attrs()) :: %User{}
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> CloudDbUi.Accounts.create_user()

    user
  end

  @spec extract_user_token(function()) :: String.t()
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")

    token
  end
end
