defmodule CloudDbUi.Query do
  alias Ecto.Query

  # TODO: remove?

  #@doc """
  #Import `Ecto.Query`, replacing only `&Ecto.Query.join/5`
  #with &CloudDbUi.Query.join/5.
  #"""
  #@spec __using__(keyword()) :: Macro.t()
  #defmacro __using__(_opts) do
  #  quote do
  #    import Ecto.Query, except: [join: 5]
  #    import CloudDbUi.Query
  #  end
  #end

  @doc """
  Check whether a named `:as` binding for `join()`ing already exists
  in the `query`.
  """
  @spec joined?(%Query{}, atom() | nil) :: boolean()
  def joined?(%Query{} = _query, nil), do: false

  def joined?(%Query{} = query, as) when is_atom(as) do
    as in Enum.map(query.joins, &(&1.as))
  end

  @doc """
  A wrapper of `&Ecto.Query.join/5` for "has many" associations.
  Joins on the ID field and expects the name of this field
  in the associated table to be equal to `named_binding` with appended
  "_id".
  """
  @spec join_many(%Query{}, atom(), atom()) :: Macro.t()
  defmacro join_many(query, named_binding, assoc) do
    quote do
      unquote(join(query, :left, named_binding, :many, assoc, assoc))
    end
  end

  @spec join_many(%Query{}, atom(), atom(), atom()) :: Macro.t()
  defmacro join_many(query, named_binding, assoc, as) do
    quote do
      unquote(join(query, :left, named_binding, :many, assoc, as))
    end
  end

  @spec join_many(%Query{}, atom(), atom(), atom(), atom()) ::
          Macro.t()
  defmacro join_many(query, qual, named_binding, assoc, as) do
    quote do
      unquote(join(query, qual, named_binding, :many, assoc, as))
    end
  end

  @doc """
  A wrapper of `&Ecto.Query.join/5` for "has one" associations.
  Joins on the ID field and expects the name of this field
  in the main table to be equal to `assoc` with appended "_id".
  """
  @spec join_one(%Query{}, atom(), atom()) :: Macro.t()
  defmacro join_one(query, named_binding, assoc) do
    quote do
      unquote(join(query, :left, named_binding, :one, assoc, assoc))
    end
  end

  @spec join_one(%Query{}, atom(), atom(), atom()) :: Macro.t()
  defmacro join_one(query, named_binding, assoc, as) do
    quote do
      unquote(join(query, :left, named_binding, :one, assoc, as))
    end
  end

  @spec join_one(%Query{}, atom(), atom(), atom(), atom()) ::
          Macro.t()
  defmacro join_one(query, qual, named_binding, assoc, as) do
    quote do
      unquote(join(query, qual, named_binding, :one, assoc, as))
    end
  end

  @spec join(%Query{}, atom(), atom(), :one | :many, atom(), atom()) ::
          {{atom(), list(), list()}, list(), list()}
  defp join(query, qual, named_binding, cardinality, assoc, as) do
    id_field_prefix =
      case cardinality do
        :one -> assoc
        :many -> named_binding
      end

    quote do
      Ecto.Query.join(
        unquote(query),
        unquote(qual),
        [{unquote(named_binding), x_}],
        y_ in assoc(x_, unquote(assoc)),
        [on: unquote(on(id_field_prefix, cardinality)), as: unquote(as)]
      )
    end
  end

  # The value of the `:on` option for &Ecto.Query.join/5.
  @spec on(String.t(), :one | :many) :: {atom(), list(), list()}
  defp on(prefix, :many) do
    quote do
      x_.id == field(y_, unquote(String.to_existing_atom("#{prefix}_id")))
    end
  end

  defp on(prefix, :one) do
    quote do
      y_.id == field(x_, unquote(String.to_existing_atom("#{prefix}_id")))
    end
  end
end
