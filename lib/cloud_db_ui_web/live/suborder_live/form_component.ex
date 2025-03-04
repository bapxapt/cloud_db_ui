defmodule CloudDbUiWeb.SubOrderLive.FormComponent do
  use CloudDbUiWeb, :live_component

  import CloudDbUiWeb.{Utilities, Form}

  alias CloudDbUi.{Orders, Products}
  alias CloudDbUi.Orders.{Order, SubOrder}
  alias CloudDbUi.Products.Product
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form

  @type params :: CloudDbUi.Type.params()
  @type errors :: CloudDbUi.Type.errors()

  # TODO: maybe keep a queue of {order_id, error | nil}?

  # TODO: maybe keep a queue of {product_id, error | nil}?

  # TODO: editable position adding time (required when editing,
  # TODO: but if left empty in :new, put current time in UTC)
    # TODO: validate with Changeset.validator_not_in_the_future()
  # TODO: would need an extra field in the data base table (added_at?)

  # Expected `@action`s: `:edit` (from `/sub-orders/:id/edit`),
  # `:edit_suborder` (from `/orders/:id/show/:s_id/edit`).
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
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
          label={label_order_id(@fetched_order, @form)}
          step="1"
          min="1"
          phx-debounce="blur"
        />
        <.input
          :if={@admin}
          field={@form[:product_id]}
          type="number"
          label={label_product_id(@fetched_product, @form)}
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
            :if={display_current_unit_price?(@admin, @fetched_product, @form)}
            title="Current unit price of the product"
          >
            PLN <%= format(@fetched_product.unit_price) %>
          </:item>
          <:item
            :if={@action != :new}
            title="Position adding date and time (UTC)"
          >
            <%= format(@form[:inserted_at].value) %>
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
    |> maybe_assign_fetched_order(order)
    |> maybe_assign_fetched_product(product)
    |> assign(form: to_form(changeset, [action: :validate]))
  end

  # A user can edit only `:quantity` of a sub-order.
  defp validate_suborder(socket, suborder_params) do
    changeset =
      Orders.change_suborder_quantity(
        socket.assigns.suborder,
        suborder_params
      )

    assign(socket, :form, to_form(changeset, [action: :validate]))
  end

  # Any input field has any error. This is needed to prevent
  # saving with an "order not found" and/or with a "product not found"
  # error (because the `:fetched_order` and/or the `fetched_product`
  # would not get replaced with a `nil`).
  @spec save_suborder(%Socket{}, atom(), params()) :: %Socket{}
  defp save_suborder(socket, _act, _p) when socket.assigns.form.errors != [] do
    socket
  end

  # Only an admin may manually create sub-orders: `/sub-orders/new`
  # is accessible only to admins.
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
         action,
         suborder_params
       ) when action in [:edit, :edit_suborder] do
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

    notify_parent({:saved, suborder_new})
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
    assign(socket, :form, to_form(set, [action: :validate]))
  end

  # Get an order from the data base, unless:
  #
  #   - `id` is not a valid ID (return `nil`);
  #   -`socket.assigns.fetched_order != nil`, and `id` matches the ID
  #     of the `:fetched_order` (return `socket.assigns.fetched_order`);
  #   - `suborder.order != nil`, and `id` matches the ID of that `:order`
  #     (return `suborder.order`).
  @spec maybe_get_order(%Socket{}, params()) :: %Order{} | nil
  defp maybe_get_order(
         %{assigns: %{suborder: suborder, fetched_order: order}},
         %{"order_id" => untrimmed_id} = _suborder_params
       ) do
    id = String.trim(untrimmed_id)

    cond do
      !valid_id?(id) -> nil
      order && id == "#{order.id}" -> order
      suborder.order && id == "#{suborder.order.id}" -> suborder.order
      true -> Orders.get_order_with_user(id)
    end
  end

  # Get a product from the data base, unless:
  #
  #   - `id` is not a valid ID (return `nil`);
  #   -`socket.assigns.fetched_product != nil`, and `id` matches the ID
  #     of the `:fetched_product` (return `socket.assigns.fetched_product`);
  #   - `suborder.product != nil`, and `id` matches the ID of that
  #     `:product` (return `suborder.product`).
  @spec maybe_get_product(%Socket{}, params()) :: %Product{} | nil
  defp maybe_get_product(
         %{assigns: %{suborder: suborder, fetched_product: prod}},
         %{"product_id" => untrimmed_id} = _suborder_params
       ) do
    id = String.trim(untrimmed_id)

    cond do
      !valid_id?(id) -> nil
      prod && id == "#{prod.id}" -> prod
      suborder.product && id == "#{suborder.product.id}" -> suborder.product
      true -> Products.get_product_with_type(id)
    end
  end

  # Do not replace an existing value of `:fetched_order` with `nil`.
  @spec maybe_assign_fetched_order(%Socket{}, %Order{} | nil) :: %Socket{}
  defp maybe_assign_fetched_order(socket, nil), do: socket

  defp maybe_assign_fetched_order(socket, %Order{} = order) do
    assign(socket, :fetched_order, order)
  end

  # Do not replace an existing value of `:fetched_product` with `nil`.
  @spec maybe_assign_fetched_product(%Socket{}, %Product{} | nil) :: %Socket{}
  defp maybe_assign_fetched_product(socket, nil), do: socket

  defp maybe_assign_fetched_product(socket, %Product{} = product) do
    assign(socket, :fetched_product, product)
  end

  # If no `errors` related to `:unit_price` or to `:quantity`,
  # `format()` `:subtotal` with default values.
  @spec maybe_format_subtotal(%Form{}) :: String.t()
  defp maybe_format_subtotal(form) do
    related_errors =
      form.errors
      |> Map.new()
      |> Map.take([:unit_price, :quantity])

    maybe_format(form[:subtotal].value, related_errors == %{}, "PLN ")
  end

  # `ord`er (`:fetched_order`) has been fetched from the data base
  # after inputting an order ID.
  @spec label_order_id(%Order{} | nil, %Form{}) :: String.t()
  defp label_order_id(order, %Form{} = form) do
    label_order_id(
      order,
      has_error?(form, :order_id, [:order_id_unpaid], :exclude)
    )
  end

  # A non-`nil` `user`, and no `:order_id` error (or only an error
  # with `validation: :order_id_unpaid`).
  @spec label_order_id(%Order{} | nil, boolean()) :: String.t()
  defp label_order_id(%Order{} = order, false = _error_exists?) do
    Kernel.<>(
      "Order ID (#{if !order.paid_at, do: "un"}paid, ",
      "belongs to ID #{order.user.id} #{order.user.email})"
    )
  end

  # A `nil` (or an `%Ecto.Association.NotLoaded{}`) `order`,
  # and/or an `:order_id` error that has a `:validation`
  # different from `:order_id_unpaid`.
  defp label_order_id(_order, _error_exists?), do: "Order ID"

  # `product` (`:fetched_product`) has been fetched from the data base
  # after inputting a product ID.
  @spec label_product_id(%Product{} | nil, %Form{}) :: String.t()
  defp label_product_id(product, %Form{} = form) do
    label_product_id(
      product,
      has_error?(form, :product_id, [:product_id_orderable], :exclude)
    )
  end

  # A non-`nil` `product`, and no `:product_id` error (or only an error
  # with `validation: :product_id_orderable`).
  @spec label_product_id(%Product{} | nil, boolean()) :: String.t()
  defp label_product_id(%Product{} = product, false = _error_exists?) do
    Kernel.<>(
      "Product ID ",
      "(#{if !product.orderable, do: "non-"}orderable, \"#{product.name}\")"
    )
  end

  # A `nil` `product`, and/or a `:product_id` error that has
  # a `:validation` different from `:product_id_orderable`.
  defp label_product_id(_user, _error_exists?), do: "Product ID"

  @spec unit_price_label(%Form{}, %Product{} | nil) :: String.t()
  defp unit_price_label(%Form{} = form, fetched_product) do
    if unit_price_label_suffix_needed?(form, fetched_product) do
      Kernel.<>(
        "Unit price at the time of adding, PLN ",
        unit_price_label_suffix(form[:unit_price].value, fetched_product)
      )
    else
      "Unit price at the time of adding, PLN"
    end
  end

  @spec display_current_unit_price?(boolean(), %Product{} | nil, %Form{}) ::
          boolean()
  defp display_current_unit_price?(true, %Product{} = _fetched_prod, form) do
    !has_error?(form, :product_id, [:product_id_orderable], :exclude)
  end

  # Do not display the current :`unit_price` to a non-administrator,
  # or if a `fetched_product` is `nil`.
  defp display_current_unit_price?(_admin?, _fetched_product, _form), do: false

  # A return value of `unit_price_label_suffix()` does not need
  # to be appended if:
  #
  #   - there are any `:unit_price` errors;
  #   - `socket.assigns.fetched_product` is `nil`;
  #   - a product has not been found for the most recently inputted
  #     product ID (even if `fetched_product` is not `nil`).
  @spec unit_price_label_suffix_needed?(%Form{}, %Product{} | nil) :: boolean()
  defp unit_price_label_suffix_needed?(form, fetched_product) do
    cond do
      Keyword.has_key?(form.errors, :unit_price) -> false
      fetched_product == nil -> false
      has_error?(form, :product_id, :product_id_found) -> false
      true -> true
    end
  end

  @spec unit_price_label_suffix(%Decimal{} | String.t(), %Product{}) ::
          String.t()
  defp unit_price_label_suffix(saved_price, fetched_product) do
    saved_price
    |> trim()
    |> Decimal.compare(fetched_product.unit_price)
    |> case do
      :lt -> " (currently lower than the current price)"
      :eq -> " (currently equal to the current price)"
      :gt -> " (currently higher than the current price)"
    end
  end
end
