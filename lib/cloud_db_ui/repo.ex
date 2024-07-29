defmodule CloudDbUi.Repo do
  use Ecto.Repo,
    otp_app: :cloud_db_ui,
    adapter: Ecto.Adapters.Postgres
end
