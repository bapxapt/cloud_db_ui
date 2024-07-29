defmodule CloudDbUi.Type do
  @type params :: %{String.t() => String.t()}
  @type attrs :: params() | %{atom() => any()}
  @type errors :: keyword({String.t, keyword()})
  @type db_id :: integer() | String.t()
end
