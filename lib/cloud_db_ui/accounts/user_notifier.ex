defmodule CloudDbUi.Accounts.UserNotifier do
  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Mailer

  import Swoosh.Email

  @doc """
  Deliver instructions to confirm account.
  """
  @spec deliver_confirmation_instructions(%User{}, String.t()) ::
          {:ok, %{} | %Swoosh.Email{}}
  def deliver_confirmation_instructions(%User{} = user, url) do
    user.email
    |> email_body(url, "confirm your account", "create an account with us")
    |> deliver(user.email, "Confirmation instructions")
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  @spec deliver_reset_password_instructions(%User{}, String.t()) ::
          {:ok, %{} | %Swoosh.Email{}}
  def deliver_reset_password_instructions(%User{} = user, url) do
    user.email
    |> email_body(url, "reset your password", "request this change")
    |> deliver(user.email, "Reset password instructions")
  end

  @doc """
  Deliver instructions to update a user email.
  """
  @spec deliver_update_email_instructions(%User{}, String.t()) ::
          {:ok, %{} | %Swoosh.Email{}}
  def deliver_update_email_instructions(%User{} = user, url) do
    user.email
    |> email_body(url, "change your email", "request this change")
    |> deliver(user.email, "Update email instructions")
  end

  # Delivers the email using the application mailer.
  @spec deliver(String.t(), String.t(), String.t()) ::
          {:ok, %{} | %Swoosh.Email{}}
  defp deliver(email_body, recipient, subject) do
    email_message =
      new()
      |> to(recipient)
      |> from({"CloudDbUi", "contact@example.com"})
      |> subject(subject)
      |> text_body(email_body)

    with {:ok, _metadata} <- Mailer.deliver(email_message) do
      if !Application.get_env(:cloud_db_ui, :dev_routes) do
        Swoosh.Adapters.Local.Storage.Memory.delete_all()
      end

      {:ok, email_message}
    end
  end

  @spec email_body(String.t(), String.t(), String.t(), String.t()) ::
          String.t()
  defp email_body(e_mail, url, consequence, cause) do
    """

    ==============================

    Hi, #{e_mail},

    You can #{consequence} by visiting the URL below:

    #{url}

    If you didn't #{cause}, please ignore this.

    ==============================
    """
  end
end
