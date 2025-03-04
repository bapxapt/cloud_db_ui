defmodule CloudDbUi.Type do
  @type params() :: %{String.t() => [String.t()] | String.t() | params()}
  @type attrs() :: params() | %{atom() => any()}
  @type error() :: {String.t, keyword()}
  @type errors() :: keyword(error())
  @type db_id() :: integer() | String.t()
  @type redirect() :: %{flash: String.t(), to: String.t()}
  @type redirect_error() :: {:error, {:redirect | :live_redirect, redirect()}}
  @type upload_entry() :: %{atom() => non_neg_integer() | binary()}
end
