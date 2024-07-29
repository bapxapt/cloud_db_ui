defmodule CloudDbUiWeb.UserSessionController do
  use CloudDbUiWeb, :controller

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.{UserAuth, FlashTimed}

  @type params() :: CloudDbUi.Type.params()

  @spec create(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def create(%Plug.Conn{} = conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(%Plug.Conn{} = conn, params) do
    create(conn, params, "Welcome back!")
  end

  @spec create(%Plug.Conn{}, params(), String.t()) :: %Plug.Conn{}
  defp create(
         %Plug.Conn{} = conn,
         %{"user" => %{"email" => email, "password" => pass} = user_params},
         info_title
       ) do
    create(
      conn,
      user_params,
      info_title,
      Accounts.get_user_by_email_and_password(String.trim(email), pass)
    )
  end

  @spec create(%Plug.Conn{}, params(), String.t(), %User{} | nil) ::
          %Plug.Conn{}
  defp create(%Plug.Conn{} = conn, user_params, _info_title, nil) do
    # In order to prevent user enumeration attacks,
    # don't disclose whether the e-mail is registered.
    conn
    |> FlashTimed.put(:error, "Invalid e-mail or password.")
    |> put_flash(:email, String.slice(user_params["email"], 0, 160))
    |> redirect(to: ~p"/users/log_in")
  end

  defp create(%Plug.Conn{} = conn, user_params, _, %User{active: false}) do
    conn
    |> FlashTimed.put(:error, "The account has been deactivated.")
    |> put_flash(:email, String.slice(user_params["email"], 0, 160))
    |> redirect(to: ~p"/users/log_in")
  end

  defp create(%Plug.Conn{} = conn, user_params, info_title, user) do
    conn
    |> FlashTimed.put(:info, info_title)
    |> UserAuth.log_in_user(user, user_params)
  end

  @spec delete(%Plug.Conn{}, params()) :: %Plug.Conn{}
  def delete(%Plug.Conn{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> FlashTimed.put(:error, "You are not logged in.")
    # The `"DELETE /users/log_out"` test
    # in `user_session_controller_test.exs` hints that `log_out_user()`
    # should be called in all cases.
    |> UserAuth.log_out_user()
  end

  def delete(%Plug.Conn{} = conn, _params) do
    conn
    |> FlashTimed.put(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
