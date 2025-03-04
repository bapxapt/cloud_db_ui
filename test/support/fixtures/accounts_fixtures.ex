defmodule CloudDbUi.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CloudDbUi.Accounts` context.
  """

  alias CloudDbUi.Accounts.User

  @type attrs() :: CloudDbUi.Type.attrs()

  @spec unique_username() :: String.t()
  def unique_username(), do: "user_#{System.unique_integer([:positive])}"

  @spec unique_email() :: String.t()
  def unique_email(), do: unique_username() <> "@example.com"

  @spec valid_password() :: String.t()
  def valid_password(), do: "Test123."

  @spec valid_user_attributes() :: attrs()
  def valid_user_attributes() do
    e_mail = unique_email()
    password = valid_password()

    %{
      email: e_mail,
      email_confirmation: e_mail,
      password: password,
      password_confirmation: password,
      balance: 0
    }
  end

  @doc """
  Generate a user.
  """
  @spec user_fixture(attrs()) :: %User{}
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> maybe_put_password_confirmation()
      |> Enum.into(valid_user_attributes())
      |> CloudDbUi.Accounts.create_user()

    user
  end

  @spec maybe_put_password_confirmation(attrs()) :: attrs()
  defp maybe_put_password_confirmation(%{password: pass} = attrs)
       when not is_map_key(attrs, :password_confirmation) do
    Map.put_new(attrs, :password_confirmation, pass)
  end

  # No `:password` in `attrs`, or `attrs` already contain
  # `:password_confirmation`.
  defp maybe_put_password_confirmation(attrs), do: attrs

  # TODO: a function that takes a function that takes a string?

  @spec extract_user_token(function()) :: String.t()
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")

    token
  end
end
