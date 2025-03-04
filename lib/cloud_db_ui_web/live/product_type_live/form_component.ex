defmodule CloudDbUiWeb.ProductTypeLive.FormComponent do
  use CloudDbUiWeb, :live_component

  import CloudDbUiWeb.{Utilities, HTML}
  import CloudDbUi.{Changeset, StringQueue}

  alias CloudDbUi.Products
  alias CloudDbUi.Products.ProductType
  alias Phoenix.LiveView.Socket
  alias Ecto.Changeset

  @type params :: CloudDbUi.Type.params()

  # The maximal length of the `:taken_names` queue.
  @taken_names_limit 10

  # TODO: maybe keep a queue of valid names?

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
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
          data-value="60"
          phx-hook="CharacterCounter"
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
  def mount(socket), do: {:ok, assign_queue(socket, :taken_names)}

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
         %{"name" => name} = type_params
       ) do
    changeset =
      Products.change_product_type(
        type,
        type_params,
        validate_unique_constraint?(name, socket)
      )
      |> maybe_add_unique_constraint_error(
        :name,
        in_queue?(socket.assigns.taken_names, name)
      )

    socket
    |> assign(:form, to_form(changeset, [action: :validate]))
    |> maybe_add_taken(:taken_names, changeset, :name, @taken_names_limit)
  end

  # Any input field has any error. This is needed to prevent
  # `update_product_type()` or `create_product_type()`
  # from performing unnecessary unique constraint checks
  # (querying the data base).
  @spec save_product_type(%Socket{}, atom(), params()) :: %Socket{}
  defp save_product_type(socket, _, _) when socket.assigns.form.errors != [] do
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
  defp handle_saving_result({:ok, type}, socket, flash_msg) do
    type_new = Map.replace!(type, :products, socket.assigns.type.products)

    case socket.assigns.action do
      :new ->
        notify_parent({:saved, type_new, true})

      :edit ->
        refilter? =
          CloudDbUiWeb.Flop.refilter?(
            socket.assigns.type,
            type_new,
            [:name, :description, :assignable]
          )

        notify_parent({:saved, type_new, refilter?})
    end

    notify_parent({:put_flash, :info, flash_msg})
    push_patch(socket, [to: socket.assigns.patch])
  end

  # Failure.
  @spec handle_saving_result({:error, %Changeset{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:error, %Changeset{} = set}, socket, _flsh_msg) do
    assign(socket, :form, to_form(set, [action: :validate]))
  end

  # Validation of a unique constraint is not needed if:
  #
  #   - the only change of `:name` that happened is an addition
  #     of a trimmable whitespace or a case change of a letter;
  #   - the `name` is in `socket.assigns.taken_names`;
  #   - the `name` is the same as `type.name`.
  @spec validate_unique_constraint?(String.t(), %Socket{}) :: boolean()
  defp validate_unique_constraint?(name, %Socket{assigns: assigns} = socket) do
    cond do
      !significant_change?(name, assigns.form.params["name"]) -> false
      in_queue?(socket.assigns.taken_names, name) -> false
      trim_downcase(name) == String.downcase(assigns.type.name) -> false
      true -> true
    end
  end
end
