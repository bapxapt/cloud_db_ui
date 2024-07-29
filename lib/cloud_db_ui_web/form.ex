defmodule CloudDbUiWeb.Form do
  alias CloudDbUi.Changeset
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form

  @type error() :: CloudDbUi.Type.error()

  @doc """
  Add an `error` to `form.errors` under a `field` key.
  """
  @spec add_form_error(%Form{}, atom(), error()) :: %Form{}
  def add_form_error(%Form{} = form, field, error) do
    Map.update!(form, :errors, &Keyword.put(&1, field, error))
  end

  @spec add_form_error(%Socket{}, atom(), error()) :: %Socket{}
  def add_form_error(%Socket{} = socket, field, error) do
    add_form_error(socket, field, error, :form)
  end

  @spec add_form_error(%Socket{}, atom(), error(), atom()) :: %Socket{}
  def add_form_error(%Socket{} = socket, field, error, form_field) do
    Phoenix.Component.assign(
      socket,
      form_field,
      add_form_error(socket.assigns[form_field], field, error)
    )
  end

  @doc """
  Remove errors corresponding to `fields` from `form.errors`.
  """
  @spec delete_form_errors(%Form{}, [atom()]) :: %Form{}
  def delete_form_errors(%Form{} = form, fields) do
    Map.update!(form, :errors, &Keyword.drop(&1, fields))
  end

  @doc CloudDbUiWeb.Utilities.get_doc(Changeset, :get_errors, 2)
  @spec get_errors(%Ecto.Changeset{} | %Form{}, [atom()]) ::
          %{atom() => [error()]}
  def get_errors(form, fields), do: Changeset.get_errors(form, fields)

  @doc CloudDbUiWeb.Utilities.get_doc(Changeset, :has_error?, 2)
  @spec has_error?(%Ecto.Changeset{} | %Form{}, atom()) :: boolean()
  def has_error?(form, field), do: Changeset.has_error?(form, field)

  @spec has_error?(%Ecto.Changeset{} | %Form{}, atom(), atom()) :: boolean()
  def has_error?(form, field, validation) do
    Changeset.has_error?(form, field, validation)
  end

  @spec has_error?(%Ecto.Changeset{} | %Form{}, atom(), [atom()], atom()) ::
          boolean()
  def has_error?(form, field, validations, operator) do
    Changeset.has_error?(form, field, validations, operator)
  end

  @doc """
  Add a unique constraint error for the `field`, if both conditions
  are true:

    - `add?` is `true`;
    - the `form` does not have an unique constraint error
      corresponding to the `field`.
  """
  @spec maybe_add_unique_constraint_error(
          %Form{},
          atom(),
          boolean(),
          String.t()
        ) :: %Form{}
  def maybe_add_unique_constraint_error(
        %Form{} = form,
        field,
        add? \\ true,
        msg \\ "has already been taken"
      ) do
    if !add? or has_error?(form, field, :unsafe_unique) do
      form
    else
      add_form_error(form, field, Changeset.unique_constraint_error(field, msg))
    end
  end
end
