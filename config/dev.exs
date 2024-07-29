import Config

# Configure the data base.
config :cloud_db_ui, CloudDbUi.Repo,
  url: System.get_env("DATABASE_URL") ||
    "ecto://postgres:root@localhost:5432/cloud_db_ui_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :cloud_db_ui, CloudDbUiWeb.Endpoint,
  # Binding to loopback IPv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: false,
  secret_key_base: "GUvXn5GcD+JE9R2AQu5fXStEmvZgc8gEqJEJmX0ag05UJyyKzcJ9mOKc6YWKwA7X",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :cloud_db_ui, CloudDbUiWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/cloud_db_ui_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for the dashboard and for the mailbox.
config :cloud_db_ui, dev_routes: true

# Do not include metadata nor timestamps in development logs.
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation.
config :phoenix, :plug_init_mode, :runtime

# Include HEEx debug annotations as HTML comments in rendered markup.
config :phoenix_live_view, :debug_heex_annotations, true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

config :cloud_db_ui, CloudDbUiWeb.ImageServer,
  hostname: System.get_env("IMAGE_SERVER_HOST", "localhost:25478"),
  token_ro: System.get_env("IMAGE_SERVER_RO_TOKEN"),
  token_rw: System.get_env("IMAGE_SERVER_RW_TOKEN")
