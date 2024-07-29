defmodule CloudDbUiWeb.ProductTypeLive.FormComponent do
  use CloudDbUiWeb, :live_component

  alias CloudDbUi.Products
  alias CloudDbUi.Products.ProductType
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.HTML

  @type params :: CloudDbUi.Type.params()

  # TODO: maybe keep a set of trimmed and down-cased e-mails and add to it each time we hit an "already taken" error?

  # TODO: characters get counted with a phx-debouce delay in the "Name" field due the the field emitting no events
    # TODO: try client-side JS?

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>
          Use this form to manage product type records in your database.
        </:subtitle>
      </.header>
      <.simple_form
        for={@form}
        id="product-type-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:name]}
          type="text"
          label={label_text("Name", @form[:name].value, 60)}
          phx-debounce="blur"
        />
        <.input
          field={@form[:description]}
          type="textarea"
          label={label_text("Description", @form[:description].value, 200)}
        />
        <.input
          field={@form[:assignable]}
          type="checkbox"
          label="Assignable to products"
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save product type</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(socket), do: {:ok, socket}

  @impl true
  def update(%{type: type} = assigns, socket) do
    socket_new =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn ->
        to_form(Products.change_product_type(type))
      end)

    {:ok, socket_new}
  end

  @impl true
  def handle_event("validate", %{"product_type" => type_params}, socket) do
    {:noreply, validate_product_type(socket, type_params)}
  end

  def handle_event("save", %{"product_type" => type_params}, socket) do
    {:noreply, save_product_type(socket, socket.assigns.action, type_params)}
  end

  @spec validate_product_type(%Socket{}, params()) :: %Socket{}
  defp validate_product_type(
         %{assigns: %{type: type}} = socket,
         type_params
       ) do
    changeset =
      Products.change_product_type(
        type,
        type_params,
        significant_name_change?(type_params, socket),
        socket.assigns.form.errors
      )

    assign(socket, form: to_form(changeset, [action: :validate]))
  end

  # Any input field has any error. This is needed to prevent
  # `update_product_type()` or `create_product_type()`
  # from performing unnecessary unique constraint checks
  # (querying the data base).
  @spec save_product_type(%Socket{}, atom(), params()) :: %Socket{}
  defp save_product_type(socket, _action, _type_params)
       when socket.assigns.form.errors != [] do
    socket
  end

  defp save_product_type(socket, :edit, type_params) do
    socket.assigns.type
    |> Products.update_product_type(type_params)
    |> handle_saving_result(
      socket,
      "Product type ID #{socket.assigns.type.id} updated successfully."
    )
  end

  defp save_product_type(socket, :new, type_params) do
    type_params
    |> Products.create_product_type()
    |> handle_saving_result(socket, "Product type created successfully.")
  end

  # Success.
  @spec handle_saving_result({:ok, %ProductType{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:ok, type_new}, socket, flash_msg) do
    notify_parent(
      {:saved, Map.replace!(type_new, :products, socket.assigns.type.products)}
    )

    notify_parent({:put_flash, :info, flash_msg})
    push_patch(socket, [to: socket.assigns.patch])
  end

  # Failure.
  @spec handle_saving_result(
          {:error, %Ecto.Changeset{}},
          %Socket{},
          String.t()
        ) :: %Socket{}
  defp handle_saving_result({:error, %Ecto.Changeset{} = set}, socket, _msg) do
    assign(socket, form: to_form(set))
  end

  # Check whether the `:name` field value differs from its previous
  # state or from `type.name` only by a whitespace or only by a letter
  # case change.
  @spec significant_name_change?(params(), %Socket{}) :: boolean()
  defp significant_name_change?(
         %{"name" => name} = _user_params,
         %{assigns: %{form: %{params: prev_params}, type: type}} = _socket
       ) do
    trimmed_downcased = trim_downcase(name)

    cond do
      trimmed_downcased == trim_downcase(prev_params["name"]) -> false
      trimmed_downcased == type.name -> false
      true -> true
    end
  end

  @spec notify_parent(any()) :: any()
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
