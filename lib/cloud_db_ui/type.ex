defmodule CloudDbUi.Type do
  @type params :: %{String.t() => String.t()}
  @type attrs :: params() | %{atom() => any()}
  @type error :: {String.t, keyword()}
  @type errors :: keyword(error())
  @type db_id :: integer() | String.t()
  @type redirect :: %{flash: String.t(), to: String.t()}
end
