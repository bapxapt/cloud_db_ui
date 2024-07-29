defmodule CloudDbUi.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add(:paid_at, :utc_datetime_usec, [null: true, default: nil])

      add(
        :user_id,
        references(:users, [on_delete: :delete_all]),
        [null: false]
      )

      timestamps([type: :utc_datetime])
    end

    create index(:orders, [:user_id])
  end
end
