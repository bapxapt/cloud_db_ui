defmodule CloudDbUi.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use CloudDbUi.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias Ecto.Changeset
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias CloudDbUi.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import CloudDbUi.DataCase
    end
  end

  setup tags do
    CloudDbUi.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(CloudDbUi.Repo, shared: not tags[:async])

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  @spec errors_on(%Changeset{}) :: %{atom() => [String.t()]}
  def errors_on(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        "#{Keyword.get(opts, String.to_existing_atom(key), key)}"
      end)
    end)
  end

  @spec errors_on({:error, %Changeset{}}) :: %{atom() => [String.t()]}
  def errors_on({:error, %Changeset{} = changeset}), do: errors_on(changeset)

  @doc """
  Set an existing order as paid for. No other changes.
  This helps when a paid order with sub-orders is needed.
  """
  @spec set_as_paid(%Order{}, %User{}) :: %Order{}
  def set_as_paid(%Order{paid_at: nil} = order, %User{} = user)
      when order.user_id == user.id do
    {:ok, paid} =
      order
      |> Orders.payment_changeset()
      |> Orders.pay_for_order()

    paid
  end

  @doc """
  Update `:inserted_at` directly, bypassing the context.
  """
  @spec update_inserted_at(struct(), String.t()) ::
          {:ok, struct()} | {:error, %Ecto.Changeset{}}
  def update_inserted_at(object, inserted_at) do
    update_bypassing_context(object, %{inserted_at: inserted_at})
  end

  @doc """
  Update arbitrary fields directly, bypassing the context.
  """
  @spec update_bypassing_context(struct(), %{atom() => any()}) ::
          {:ok, struct()} | {:error, %Ecto.Changeset{}}
  def update_bypassing_context(object, data) do
    object
    |> Ecto.Changeset.cast(data, Map.keys(data), [empty_values: []])
    |> CloudDbUi.Repo.update()
  end
end
