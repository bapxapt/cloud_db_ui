import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :pbkdf2_elixir, :rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :cloud_db_ui, CloudDbUi.Repo,
  url: System.get_env("DATABASE_URL") ||
    "ecto://postgres:root@localhost:5432/cloud_db_ui_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cloud_db_ui, CloudDbUiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],
  secret_key_base: "A3SdTeR+vYzkt+MUnIJmMPf/kGZtfLN2xd4Zud94nDQ7oBZEc2ZNkvjQz4FF7TjS",
  server: true

# In test we don't send emails.
config :cloud_db_ui, CloudDbUi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test.
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation.
config :phoenix, :plug_init_mode, :runtime

# Enable the routes for mocking `ImageServer`.
config :cloud_db_ui, mock_routes: true

config :cloud_db_ui, CloudDbUiWeb.ImageServer,
  hostname: "localhost:4001/mock",
  token_ro: "mock_token_ro_6e725b",
  token_rw: "mock_token_rw_b4a3c0",
  timeout: 300
