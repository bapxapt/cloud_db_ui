defmodule CloudDbUiWeb.Form do
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form

  @type error() :: CloudDbUi.Type.error()

  @doc """
  Add an `error` to `form.errors` under a `field` key.
  """
  @spec add_form_error(%Socket{}, atom(), error()) :: %Socket{}
  def add_form_error(%Socket{assigns: %{form: form}} = socket, field, error) do
    Phoenix.Component.assign(socket, :form, add_form_error(form, field, error))
  end

  @spec add_form_error(%Form{}, atom(), error()) :: %Form{}
  def add_form_error(%Form{} = form, field, error) do
    Map.update!(form, :errors, &Keyword.put(&1, field, error))
  end

  @doc """
  Remove `fields` keys from `form.errors`.
  """
  @spec delete_form_errors(%Form{}, [atom()]) :: %Form{}
  def delete_form_errors(%Form{} = form, fields) do
    Map.update!(form, :errors, &Keyword.drop(&1, fields))
  end

  @doc """
  Check whether in `form.errors` any error (with an optional
  `validation`) exists for a `field`.

  Also can accept a list of `validations` and an `op`erator.
  If the `op`erator is `:include`, any errors with `:validation`
  in `validations` count. If the `op`erator is `:exclude`, any
  errors with `:validation` not in `validations` (or without
  `:validation` at all) count.
  """
  @spec has_error?(%Form{}, atom()) :: boolean()
  def has_error?(form, field), do: Keyword.get_values(form.errors, field) != []

  @spec has_error?(%Form{}, atom(), atom()) :: boolean()
  def has_error?(form, field, validation) do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.any?(fn {_message, extra_info} = _error ->
      Keyword.get(extra_info, :validation) == validation
    end)
  end

  @spec has_error?(%Form{}, atom(), [atom()], atom()) :: boolean()
  def has_error?(form, field, validations, operator)
      when operator in [:include, :exclude] do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.any?(fn {_msg, keys} ->
      case operator do
        :include -> keys[:validation] in validations
        :exclude -> keys[:validation] not in validations
      end
    end)
  end
end
