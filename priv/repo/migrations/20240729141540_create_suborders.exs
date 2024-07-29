defmodule CloudDbUi.Repo.Migrations.CreateSubOrders do
  use Ecto.Migration

  def change do
    create table(:suborders) do
      add :product_id, references(:products, [on_delete: :nothing]), null: false
      add :order_id, references(:orders, [on_delete: :nothing]), null: false
      add :quantity, :integer, null: false
      # A snap-shot of price, because prices might change.
      add :unit_price, :decimal, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:suborders, [:product_id])
    create index(:suborders, [:order_id])
  end
end
