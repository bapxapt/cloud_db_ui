defmodule CloudDbUiWeb.SubOrderLive.FormComponent do
  use CloudDbUiWeb, :live_component

  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Orders.SubOrder
  alias CloudDbUi.Products
  alias CloudDbUi.Products.Product
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.Utilities

  @type params :: CloudDbUi.Type.params()
  @type errors :: CloudDbUi.Type.errors()

  # TODO: explicitly error out :quantity (use pattern="" or validate_format() in a changeset)?

  # Expected `@action`s: `:edit` (from `/sub-orders/:id/edit`),
  # `:edit_suborder` (from `/orders/:id/show/:s_id/edit`).
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle></:subtitle>
      </.header>
      <.simple_form
        for={@form}
        id="suborder-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          :if={@admin}
          field={@form[:order_id]}
          type="number"
          label={label_order_id(@fetched_order)}
          step="1"
          min="1"
          phx-debounce="blur"
        />
        <.input
          :if={@admin}
          field={@form[:product_id]}
          type="number"
          label={label_product_id(@fetched_product)}
          step="1"
          min="1"
          phx-debounce="blur"
        />
        <.list width_class="w-4/10">
          <:item :if={!@admin} title="Product ID">
            <%= @form[:product_id].value %>
          </:item>
          <:item :if={!@admin} title="Product name">
            <%= @fetched_product.name %>
          </:item>
          <:item :if={!@admin} title="Unit price at the time of adding">
            PLN <%= format(@form[:unit_price].value) %>
          </:item>
          <:item
            :if={@admin && @fetched_product}
            title="Current unit price of the product"
          >
            PLN <%= format(@fetched_product.unit_price) %>
          </:item>
          <:item
            :if={@action != :new}
            title="Position adding date and time (UTC)"
          >
            <%= format_date_time(@form[:inserted_at].value) %>
          </:item>
        </.list>
        <.input
          :if={@admin}
          field={@form[:unit_price]}
          label={unit_price_label(@form, @fetched_product)}
          type="text"
          inputmode="decimal"
          value={maybe_format(@form, :unit_price)}
        />
        <.input
          field={@form[:quantity]}
          label="Quantity"
          type="number"
          min="1"
          max="100000"
          value={@form[:quantity].value || 1}
        />
        <.list width_class="w-4/10">
          <:item title="Subtotal"><%= maybe_format_subtotal(@form) %></:item>
        </.list>
        <:actions>
          <.button phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(socket), do: {:ok, socket}

  @impl true
  def update(%{suborder: suborder} = assigns, socket) do
    socket_new =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(Orders.change_suborder(suborder)) end)
      |> assign(:fetched_order, suborder.order)
      |> assign(:fetched_product, suborder.product)

    {:ok, socket_new}
  end

  @impl true
  def handle_event("validate", %{"sub_order" => suborder_params}, socket) do
    {:noreply, validate_suborder(socket, suborder_params)}
  end

  def handle_event("save", %{"sub_order" => suborder_params}, socket) do
    {:noreply, save_suborder(socket, socket.assigns.action, suborder_params)}
  end

  # An admin can edit any property of a sub-order.
  @spec validate_suborder(%Socket{}, params()) :: %Socket{}
  defp validate_suborder(
         %{assigns: %{admin: true}} = socket,
         suborder_params
       ) do
    order = maybe_get_order(socket, suborder_params)
    product = maybe_get_product(socket, suborder_params)

    changeset =
      Orders.change_suborder(
        socket.assigns.suborder,
        suborder_params,
        order,
        product
      )

    socket
    |> assign(:fetched_order, order)
    |> assign(:fetched_product, product)
    |> assign(form: to_form(changeset, [action: :validate]))
  end

  # A user can edit only `:quantity` of a sub-order.
  defp validate_suborder(socket, suborder_params) do
    changeset =
      Orders.change_suborder_quantity(
        socket.assigns.suborder,
        suborder_params
      )

    assign(socket, form: to_form(changeset, [action: :validate]))
  end

  @spec save_suborder(%Socket{}, atom(), params()) :: %Socket{}
  defp save_suborder(%{assigns: assigns} = socket, :new, suborder_params) do
    suborder_params
    |> Orders.create_suborder(assigns.fetched_order, assigns.fetched_product)
    |> handle_saving_result(socket, "Order position created successfully.")
  end

  # Saved after editing as an admin.
  # If the `:unit_price` of a product changed after the creation
  # of the sub-order, quantity can only be decreased.
  defp save_suborder(
         %{assigns: %{admin: true}} = socket,
         :edit,
         suborder_params
       ) do
    socket.assigns.suborder
    |> Orders.update_suborder(
      suborder_params,
      socket.assigns.fetched_order,
      socket.assigns.fetched_product
    )
    |> handle_saving_result(
      socket,
      "Order position ID #{socket.assigns.suborder.id} updated successfully."
    )
  end

  # Saved after editing (changing quantity) as a user.
  # If the `:unit_price` of a product changed after the creation
  # of the sub-order, quantity can only be decreased.
  defp save_suborder(socket, :edit_suborder, suborder_params) do
    socket.assigns.suborder
    |> Orders.update_suborder_quantity(suborder_params)
    |> handle_saving_result(socket, "Order position updated successfully.")
  end

  # Success.
  @spec handle_saving_result({:ok, %SubOrder{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:ok, suborder}, socket, flash_msg) do
    suborder_new =
      suborder
      |> Map.replace(:order, socket.assigns.fetched_order)
      |> Map.replace(:product, socket.assigns.fetched_product)

    notify_parent({
      :saved,
      suborder_new,
      suborder_new.quantity - socket.assigns.suborder.quantity
    })

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
    assign(socket, form: to_form(set, [action: :validate]))
  end

  # Get an order from the data base, unless:
  #
  #   - trimmed `suborder_params["order_id"]` is not a valid ID
  #     (return `nil`);
  #   - `suborder_params["order_id"]` differs
  #     from `form.params["order_id"]` (a previous value
  #     of the order ID input field) only by spaces (return whatever
  #     `:fetched_order` is in `socket.assigns`, even if `nil`);
  #   -`socket.assigns.fetched_order != nil`, and trimmed
  #     `suborder_params["order_id"]` matches the ID
  #     of the `:fetched_order` (return `socket.assigns.fetched_order`);
  #   - `suborder.order != nil`, and trimmed `suborder_params["order_id"]`
  #     matches the ID of that `:order` (return `suborder.order`).
  @spec maybe_get_order(%Socket{}, params()) :: %Order{} | nil
  defp maybe_get_order(
         %{assigns: %{suborder: suborder, fetched_order: order, form: form}},
         %{"order_id" => untrimmed_id} = _suborder_params
       ) do
    id = String.trim(untrimmed_id)

    cond do
      !valid_id?(id) -> nil
      id == trim(form.params["order_id"]) -> order
      order && id == "#{order.id}" -> order
      suborder.order && id == "#{suborder.order.id}" -> suborder.order
      true -> Orders.get_order_with_user(id)
    end
  end

  # Get a product from the data base, unless:
  #
  #   - trimmed `suborder_params["product_id"]` is not a valid ID
  #     (return `nil`);
  #   - `suborder_params["product_id"]` differs
  #     from `form.params["product_id"]` (a previous value
  #     of the product ID input field) only by spaces (return whatever
  #     `:fetched_product` is in `socket.assigns`, even if `nil`);
  #   -`socket.assigns.fetched_product != nil`, and trimmed
  #     `suborder_params["product_id"]` matches the ID
  #     of the `:fetched_product` (return `socket.assigns.fetched_product`);
  #   - `suborder.product != nil`, and trimmed `suborder_params["product_id"]`
  #     matches the ID of that `:product` (return `suborder.product`).
  @spec maybe_get_product(%Socket{}, params()) :: %Product{} | nil
  defp maybe_get_product(
         %{assigns: %{suborder: suborder, fetched_product: prod, form: form}},
         %{"product_id" => untrimmed_id} = _suborder_params
       ) do
    id = String.trim(untrimmed_id)

    cond do
      !valid_id?(id) -> nil
      id == trim(form.params["product_id"]) -> prod
      prod && id == "#{prod.id}" -> prod
      suborder.product && id == "#{suborder.product.id}" -> suborder.product
      true -> Products.get_product_with_type(id)
    end
  end

  # If no `errors` related to `:unit_price` or to `:quantity`,
  # `format()` `:subtotal` with default values.
  @spec maybe_format_subtotal(%Phoenix.HTML.Form{}) :: String.t()
  defp maybe_format_subtotal(form) do
    related_errors =
      form.errors
      |> Map.new()
      |> Map.take([:unit_price, :quantity])

    maybe_format(form[:subtotal].value, related_errors == %{}, "PLN")
  end

  # `fetched_order` is an `%Order{}` found in the data base after
  # inputting an order ID.
  @spec label_order_id(%Order{} | nil) :: String.t()
  defp label_order_id(nil = _fetched_order), do: "Order ID"

  defp label_order_id(%Order{} = fetched_order) do
    """
    Order ID
    (#{if !fetched_order.paid_at, do: "un"}paid,
    belongs to ID #{fetched_order.user.id} #{fetched_order.user.email})
    """
  end

  # `fetched_product` is a `%Product{}` found in the data base after
  # inputting a product ID.
  @spec label_product_id(%Product{} | nil) :: String.t()
  defp label_product_id(nil = _fetched_product), do: "Product ID"

  defp label_product_id(%Product{} = fetched_product) do
    """
    Product ID
    (#{if !fetched_product.orderable, do: "non-"}orderable,
    \"#{fetched_product.name}\")
    """
  end

  @spec unit_price_label(%Phoenix.HTML.Form{}, %Product{} | nil) :: String.t()
  defp unit_price_label(%Phoenix.HTML.Form{} = form, fetched_product) do
    if unit_price_label_suffix_needed?(form, fetched_product) do
      "Unit price at the time of adding, PLN"
    else
      Kernel.<>(
        "Unit price at the time of adding, PLN ",
        unit_price_label_suffix(form[:unit_price].value, fetched_product)
      )
    end
  end

  @spec unit_price_label_suffix_needed?(
          %Phoenix.HTML.Form{},
          %Product{} | nil
        ) :: boolean()
  defp unit_price_label_suffix_needed?(form, fetched_product) do
    cond do
      Keyword.has_key?(form.errors, :unit_price) -> true
      fetched_product == nil -> true
      form[:unit_price].value == nil -> true
      true -> false
    end
  end

  @spec unit_price_label_suffix(%Decimal{} | String.t(), %Product{}) ::
          String.t()
  defp unit_price_label_suffix(saved_price, fetched_product) do
    saved_price
    |> trim()
    |> Decimal.compare(fetched_product.unit_price)
    |> case do
      :lt -> " (lower than the current price)"
      :eq -> " (equal to the current price)"
      :gt -> " (higher than the current price)"
    end
  end

  @spec notify_parent(any()) :: any()
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
