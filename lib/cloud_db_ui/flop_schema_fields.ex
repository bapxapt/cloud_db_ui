defmodule CloudDbUi.FlopSchemaFields do
  alias Phoenix.LiveView.Socket

  @doc """
  Injects an `alias`, necessary module `import`s,
  and a `@behaviour` attribute.
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      alias CloudDbUi.Accounts.User
      alias Phoenix.LiveView.Socket

      import CloudDbUiWeb.Flop
      import CloudDbUi.FlopFilters

      @behaviour CloudDbUi.FlopSchemaFields
    end
  end

  @doc """
  A list of `:filterable` fields for a `@derive` `Flop.Schema`.
  """
  @callback filterable_fields() :: [atom()]

  @doc """
  A list of `:sortable` fields for a `@derive` `Flop.Schema`.
  """
  @callback sortable_fields() :: [atom()]

  @doc """
  Options for `:adapter_opts` of a `@derive` `Flop.Schema`.
  """
  @callback adapter_opts() :: keyword([atom() | keyword(keyword())])

  @doc """
  Retrieve a list of objects from the data base.
  Uses `Flop.validate_and_run()`.
  """
  @callback list_objects(%Flop{}, struct() | nil) ::
              {:ok, {[struct()], %Flop.Meta{}}} | {:error, %Flop.Meta{}}

  @doc """
  Delete an object by its ID, potentially creating a necessity to retrieve
  a new list of objects from the data base.
  """
  @callback delete_object_by_id(%Socket{}, String.t()) :: %Socket{}

  @doc """
  Return the value of `fields=""` for the `<.filter_form>`.
  """
  @callback filter_form_field_opts(struct() | nil) :: keyword(keyword())

  @doc """
  Return the list of paired "from"-"to" filter input field label texts.
  """
  @callback min_max_field_labels() :: [{String.t(), String.t()}]

  @doc """
  Options of a `type="text"` filter field without `inputmode="decimal"`.
  """
  @spec text_field_opts(String.t(), atom()) :: keyword()
  def text_field_opts(label, op \\ :ilike) do
    [op: op, label: label, type: "text"]
  end

  @doc """
  Options of a `type="text"` input field for a decimal schema field
  to support trimmable whitespaces.
  """
  @spec decimal_field_opts(String.t(), atom(), any()) :: keyword()
  def decimal_field_opts(label, op, placeholder) do
    label
    |> decimal_field_opts(op)
    |> Keyword.put_new(:placeholder, placeholder)
  end

  @spec decimal_field_opts(String.t(), atom()) :: keyword()
  def decimal_field_opts(label, op \\ :==) do
    [op: op, label: label, type: "text", inputmode: "decimal"]
  end

  @doc """
  Options of a `type="datetime-local"` input field.
  """
  @spec datetime_field_opts(String.t(), atom()) :: keyword()
  def datetime_field_opts(label, op \\ :==) do
    [op: op, label: label, type: "datetime-local"]
  end

  @doc """
  Options of a `<select>` filter field that is useful when a boolean
  schema field is not expected to have a `nil` value, thus a check box
  cannot be used, as unchecking it filters by `false` instead of clearing
  the filter.
  """
  @spec select_field_opts(String.t(), atom(), [{String.t(), any()}]) ::
          keyword()
  def select_field_opts(
        label,
        op \\ :==,
        opts \\ [{"Yes", true}, {"No", false}]
      ) do
    [op: op, label: label, type: "select", prompt: "—", options: opts]
  end
end
