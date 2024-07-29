defmodule CloudDbUi.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add(
        :product_type_id,
        references(:product_types, [on_delete: :nothing]),
        [null: false]
      )

      add(:name, :string, [null: false])
      add(:description, :string, [null: true])
      add(:unit_price, :decimal, [null: false, precision: 10, scale: 2])
      add(:orderable, :boolean, [null: false])
      add(:image_path, :string, [null: true])

      timestamps([type: :utc_datetime])
    end

    create index(:products, [:product_type_id])
  end
end
