defmodule CloudDbUi.Repo.Migrations.CreateProductTypes do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:product_types) do
      add(:name, :citext, [null: false])
      add(:description, :string, [null: true])
      add(:assignable, :boolean, [null: false])

      timestamps([type: :utc_datetime])
    end

    create unique_index(:product_types, [:name])
  end
end
