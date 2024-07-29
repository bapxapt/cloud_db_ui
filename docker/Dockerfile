FROM elixir:1.17.3

WORKDIR /cloud_db_ui_app

ENV MIX_ENV=prod

RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
# Changes to `config/runtime.exs` do not require recompiling the code.
COPY config/runtime.exs config/
COPY mix.exs mix.lock ./
COPY priv priv
COPY lib lib
COPY assets assets

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get --force --only $MIX_ENV
RUN mix deps.compile --force
RUN mix assets.deploy
RUN mix compile --force

CMD mix ecto.create && \
  mix ecto.migrate --quiet && \
  mix run priv/repo/seeds.exs && \
  mix phx.server
