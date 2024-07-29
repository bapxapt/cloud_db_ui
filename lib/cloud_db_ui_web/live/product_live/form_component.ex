defmodule CloudDbUiWeb.ProductLive.FormComponent do
  use CloudDbUiWeb, :live_component
  use CloudDbUiWeb.FlashTimed, :live_component

  alias CloudDbUi.Products
  alias CloudDbUi.Products.{Product, ProductType}
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.{Socket, UploadEntry}
  alias Ecto.Changeset

  import CloudDbUiWeb.{Utilities, HTML, Form}

  @type params :: CloudDbUi.Type.params()

  # TODO: upload a valid image, then without pressing "Cancel upload" upload an invalid file
    # TODO: the file name flickers for a split second and disappears

  # TODO: clearing/replacing image should delete the old one from the image server
    # TODO: deletion does not seem to be possible with mayth/simple-upload-server

  # Expected values of `@action`: `:new`, `:edit`.
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage product records in your database.</:subtitle>
      </.header>

      <.flash
        :if={@flash != %{}}
        id={"flash-#{FlashTimed.kind(@flash)}"}
        flash={@flash}
        kind={FlashTimed.kind(@flash)}
        title={FlashTimed.title(@flash)}
      >
        <%= hd(Map.values(@flash)) %>
      </.flash>

      <.simple_form
        for={@form}
        id="product-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:name]}
          type="text"
          label={label_text("Name", @form[:name].value, 60)}
        />

        <%= if @types != %{} do %>
          <.input
            field={@form[:product_type_id]}
            type="select"
            label="Type"
            options={Enum.map(@types, fn {id, type} -> {type.name, id} end)}
            prompt={if @action == :new, do: "—"}
          />
        <% else %>
          <.label :if={@action == :edit}>
            <%= text_no_assignable_product_types(:edit) %>.
          </.label>
          <.error :if={@action == :new}>
            <%= text_no_assignable_product_types(:new) %>
          </.error>
        <% end %>

        <.input
          field={@form[:description]}
          type="textarea"
          label={label_text("Description", @form[:description].value, 200)}
        />
        <.input
          field={@form[:unit_price]}
          type="text"
          inputmode="decimal"
          label="Unit price, PLN"
          value={maybe_format(@form, :unit_price)}
        />
        <.input
          field={@form[:orderable]}
          type="checkbox"
          label="Orderable"
        />

        <.list>
          <:item :if={@product.image_path != nil} title="Current image path">
            <%= @product.image_path %>
          </:item>
          <:item :if={@product.image_path != nil} title="Current image">
            <%= img(@product.image_path, "product image", 80, @load_images?) %>
          </:item>
        </.list>

        <.input
          :if={@product.image_path != nil}
          name="remove_image"
          type="checkbox"
          label="Remove the current image"
          checked={@remove_image?}
        />

        <.list
          :if={!@remove_image?}
          title_text_class="text-sm font-semibold leading-6 text-zinc-800"
        >
          <:item title="New image">
            <%= if @load_images? do %>
              <div phx-drop-target={@uploads.image.ref}>
                <.live_file_input upload={@uploads.image} />

                <%= for entry <- @uploads.image.entries do %>
                  <%= if upload_errors(@uploads.image, entry) == [] do %>
                    <div class="mt-2">
                      <.live_img_preview entry={entry} width="80" />
                    </div>
                  <% end %>
                  <progress value={entry.progress} max="100" />
                  <.button
                    type="button"
                    phx-target={@myself}
                    phx-disable-with="Cancelling..."
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                  >
                    Cancel upload
                  </.button>
                <% end %>
              </div>

              <progress
                :if={@form[:image_path].errors != []}
                value="0"
                max="100"
              />
              <.button
                :if={@form[:image_path].errors != []}
                type="button"
                phx-target={@myself}
                phx-disable-with="Cancelling..."
                phx-click="clear_upload_errors"
              >
                Cancel upload
              </.button>

              <%= for {error_msg, _} <- @form[:image_path].errors do %>
                <.error><%= error_msg %></.error>
              <% end %>
            <% else %>
              The image server does not respond, cannot upload new images.
            <% end %>
          </:item>
        </.list>

        <:actions>
          <.button phx-disable-with="Saving...">Save Product</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(socket), do: {:ok, prepare_socket(socket)}

  @impl true
  def update(%{product: product} = assigns, socket) do
    socket_new =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(Products.change_product(product)) end)

    {:ok, socket_new}
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, validate_product(socket, params)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("clear_upload_errors", _params, socket) do
    {:noreply, clear_upload_errors(socket)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    {:noreply, save_product(socket, socket.assigns.action, product_params)}
  end

  @spec prepare_socket(%Socket{}) :: %Socket{}
  defp prepare_socket(socket) do
    socket
    |> prepare_socket(connected?(socket))
    |> assign(:remove_image?, false)
  end

  @spec prepare_socket(%Socket{}, boolean()) :: %Socket{}
  defp prepare_socket(socket, true = _connected?) do
    socket
    |> assign(:load_images?, CloudDbUiWeb.ImageServer.up?())
    |> maybe_allow_upload(:image)
    |> assign_product_types()
    |> assign(:upload_errors, [])
  end

  defp prepare_socket(socket, false) do
    socket
    |> assign(:load_images?, false)
    |> assign(:types, [])
  end

  @spec clear_upload_errors(%Socket{}) :: %Socket{}
  defp clear_upload_errors(%Socket{assigns: %{form: form}} = socket) do
    socket
    # Clear the file name in the `<.live_file_input />`.
    |> maybe_allow_upload(:image)
    |> assign(:upload_errors, [])
    |> assign(:form, delete_form_errors(form, [:image_path]))
  end

  @spec validate_product(%Socket{}, params()) :: %Socket{}
  defp validate_product(socket, %{"product" => product_params} = params) do
    upload_errors = friendly_upload_errors(socket, :image)

    changeset =
      Products.change_product(
        socket.assigns.product,
        product_params,
        Map.get(socket.assigns.types, product_params["product_type_id"]),
        upload_errors
      )

    socket
    |> assign(:upload_errors, upload_errors)
    |> maybe_assign_remove_image_state(params["remove_image"])
    |> maybe_cancel_all_uploads(:image, params["remove_image"])
    |> maybe_cancel_invalid_uploads(:image)
    |> assign(:form, to_form(changeset, [action: :validate]))
  end

  @spec save_product(%Socket{}, atom(), params()) :: %Socket{}
  defp save_product(socket, :edit, product_params) do
    type = get_type(socket, product_params)

    socket.assigns.product
    |> Products.update_product(
      maybe_add_image_path(product_params, socket),
      type,
      socket.assigns.upload_errors
    )
    |> handle_saving_result(
      socket,
      "Product ID #{socket.assigns.product.id} updated successfully.",
      type
    )
  end

  defp save_product(socket, :new, product_params) do
    type = get_type(socket, product_params)

    product_params
    |> maybe_add_image_path(socket)
    |> Products.create_product(type, socket.assigns.upload_errors)
    |> handle_saving_result(socket, "Product created successfully.", type)
  end

  # Success.
  @spec handle_saving_result(
          {:ok, %Product{}} | {:error, %Changeset{}},
          %Socket{},
          String.t(),
          %ProductType{}
        ) :: %Socket{}
  defp handle_saving_result({:ok, product}, socket, flash_msg, type) do
    product_new =
      product
      |> Map.replace!(:orders, socket.assigns.product.orders)
      |> Map.replace!(:paid_orders, socket.assigns.product.paid_orders)
      |> Map.replace!(:product_type, type)

    case socket.assigns.action do
      :new ->
        notify_parent({:saved, product_new, true})

      :edit ->
        refilter? =
          CloudDbUiWeb.Flop.refilter?(
            socket.assigns.product,
            product_new,
            Map.keys(product_new) -- [:paid_orders, :suborders, :orders]
          )

        notify_parent({:saved, product_new, refilter?})
    end

    notify_parent({:put_flash, :info, flash_msg})

    socket
    # Prevent any `:error` flash from being copied to the parent.
    |> clear_flash(:error)
    |> push_patch([to: socket.assigns.patch])
  end

  # Failure, put an `:error` flash if the type ID selector is hidden.
  defp handle_saving_result({:error, %Changeset{} = set}, socket, _, _type) do
    socket
    |> maybe_put_flash_product_type_error(set)
    |> assign(:form, to_form(set, [action: :validate]))
  end

  # Put a product type error flash only if there are
  # no assignable product types, and a `:product_type_id`
  # error exists in `changeset.errors`.
  @spec maybe_put_flash_product_type_error(%Socket{}, %Changeset{}) ::
          %Socket{}
  defp maybe_put_flash_product_type_error(socket, set) do
    cond do
      socket.assigns.types != %{} ->
        socket

      !Keyword.has_key?(set.errors, :product_type_id) ->
        socket

      true ->
        FlashTimed.put(
          socket,
          :error,
          "Product type #{elem(set.errors[:product_type_id], 0)}.",
          __MODULE__
        )
    end
  end

  # The type selector is not hidden, `"product_type_id"` is present
  # in `product_params`, get the type ID from there.
  @spec get_type(%Socket{}, params()) :: %ProductType{} | nil
  defp get_type(socket, %{"product_type_id" => id} = _product_params) do
    Map.get(socket.assigns.types, id)
  end

  # The type selector is hidden (no assignable types),
  # no `"product_type_id"` in `product_params`, get the type
  # from the `socket` as a fall-back mechanism.
  defp get_type(socket, _), do: socket.assigns.product.product_type

  # The `ImageServer` is running.
  @spec maybe_cancel_invalid_uploads(%Socket{}, atom()) :: %Socket{}
  defp maybe_cancel_invalid_uploads(
         %{assigns: %{uploads: uploads}} = socket,
         key
       ) do
    Enum.reduce(uploads[key].entries, socket, fn entry, acc ->
      if entry.valid? do
        socket
      else
        cancel_upload(acc, key, entry.ref)
      end
    end)
  end

  # The `ImageServer` is not running, `allow_upload()` has not been
  # called (no `:upload` in `socket.assigns`).
  defp maybe_cancel_invalid_uploads(socket, _key), do: socket

  # Attempt to add `"image_path"` to `product_params` (consuming upload
  # entries in the process) only if all of the other changes are valid.
  @spec maybe_add_image_path(params(), %Socket{}) :: params()
  defp maybe_add_image_path(product_params, socket) do
    changeset =
      Products.change_product(
        socket.assigns.product,
        product_params,
        get_type(socket, product_params)
      )

    maybe_add_image_path(product_params, socket, changeset.valid?)
  end

  # An invalid changeset, do not add `"image_path"`.
  @spec maybe_add_image_path(params(), %Socket{}, boolean()) :: params()
  defp maybe_add_image_path(product_params, _socket, false = _valid_change?) do
    product_params
  end

  # The "Remove the current image" check box is checked.
  # Do not process `socket.assigns.uploads.image.entries`.
  # Clear the image by setting its path to `nil`.
  defp maybe_add_image_path(
         product_params,
         %{assigns: %{remove_image?: true}} = _socket,
         true = _valid_changeset?
         ) do
    Map.put_new(product_params, "image_path", nil)
  end

  # The image server is not running.
  # Do not process `socket.assigns.uploads.image.entries`.
  defp maybe_add_image_path(
         product_params,
         %{assigns: %{load_images?: false}} = _socket,
         true = _valid_changeset?
       ) do
    product_params
  end

  # No file has been uploaded, do not add `"image_path"`.
  # This means the current image will be retained.
  defp maybe_add_image_path(product_params, socket, true = _valid_changeset?)
       when socket.assigns.uploads.image.entries == [] do
    product_params
  end

  # A new file has been uploaded, add `"image_path"`.
  defp maybe_add_image_path(product_params, socket, true = _valid_changes?) do
    path =
      socket
      # Iterate through `socket.assigns.uploads.image.entries`
      # processing each list element (entry) with `&upload_static_file!/2`.
      # The length of `socket.assigns.uploads.image.entries`
      # is governed by `:max_entries` in `allow_upload()`.
      |> consume_uploaded_entries(:image, &upload_static_file!/2)
      |> List.first()

    Map.put_new(product_params, "image_path", path)
  end

  @spec upload_static_file!(%{atom() => String.t()}, %UploadEntry{}) ::
          {:ok, String.t()}
  defp upload_static_file!(%{path: path} = _metadata, _entry) do
    case CloudDbUiWeb.ImageServer.upload(path) do
      {201, _ct_type, %{"ok" => true, "path" => at_server}} -> {:ok, at_server}
      {:error, reason} -> raise(%HTTPoison.Error{reason: reason})
      any -> raise(%HTTPoison.Error{reason: "Upload failed: #{inspect(any)}"})
    end
  end

  # Fetch all product types from the data base and turn them
  # into a map with string IDs as keys and type names as values.
  @spec assign_product_types(%Socket{}) :: %Socket{}
  defp assign_product_types(socket) do
    assign(
      socket,
      :types,
      Map.new(Products.list_assignable_product_types(), &{"#{&1.id}", &1})
    )
  end

  # The "Remove the current image" check box has not been rendered.
  # This means the product did not have any current image.
  @spec maybe_assign_remove_image_state(%Socket{}, nil) :: %Socket{}
  defp maybe_assign_remove_image_state(socket, nil), do: socket

  # The "Remove the current image" check box has been rendered.
  @spec maybe_assign_remove_image_state(%Socket{}, String.t()) :: %Socket{}
  defp maybe_assign_remove_image_state(socket, check_box_state) do
    assign(socket, :remove_image?, to_boolean(check_box_state))
  end

  # The "Remove the current image" check box has been rendered.
  # `check_box_state` (`params["remove_image"]`) is a string,
  # convert it to a boolean value.
  @spec maybe_cancel_all_uploads(%Socket{}, atom(), String.t()) :: %Socket{}
  defp maybe_cancel_all_uploads(socket, key, check_box_state)
       when is_binary(check_box_state) do
    maybe_cancel_all_uploads(socket, key, to_boolean(check_box_state))
  end

  # The "Remove the current image" check box has not been rendered
  # (`nil`), or has been unchecked (`false`).
  @spec maybe_cancel_all_uploads(%Socket{}, atom(), false | nil) :: %Socket{}
  defp maybe_cancel_all_uploads(socket, _key, remove_image?)
       when remove_image? in [nil, false] do
    socket
  end

  # The "Remove the current image" check box has been checked.
  # The `ImageServer` is running.
  defp maybe_cancel_all_uploads(
         %{assigns: %{uploads: uploads}} = socket,
         key,
         true = _remove_image?
       ) do
    Enum.reduce(
      uploads[key].entries,
      socket,
      fn entry, acc -> cancel_upload(acc, key, entry.ref) end
    )
  end

  # The `ImageServer` is not running, `allow_upload()` has not been
  # called (no `:upload` in `socket.assigns`).
  defp maybe_cancel_all_uploads(socket, _key, _remove_image?), do: socket

  # Retrieve a list of unique user-friendly upload errors
  # from `socket.assigns.uploads[key].entries`
  # if the `ImageServer` is running, and there are any upload
  # entries. If no entries, return `socket.assigns.upload_errors`.
  @spec friendly_upload_errors(%Socket{}, atom()) :: [String.t()]
  defp friendly_upload_errors(%{assigns: %{uploads: uploads}} = socket, key) do
    if uploads[key].entries == [] do
      socket.assigns.upload_errors
    else
      uploads[key].entries
      |> Enum.map(&upload_errors(uploads[key], &1))
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.map(&friendly_upload_error(&1, uploads[key]))
    end
  end

  # The `ImageServer` is not running, `allow_upload()` has not been
  # called (no `:upload` in `socket.assigns`).
  defp friendly_upload_errors(%Socket{} = _socket, _key), do: []

  # The `ImageServer` is running.
  defp maybe_allow_upload(%{assigns: %{load_images?: true}} = socket, key) do
    allow_upload(
      socket,
      key,
      accept: ~w(.jpg .jpeg .png .bmp .gif),
      # The length of `socket.assigns.uploads[key].entries`.
      max_entries: 1,
      max_file_size: 5_242_880,
      # Begin uploading the file as soon as a file is attached
      # to the form, rather than wait until the form is submitted.
      auto_upload: true
    )
  end

  # The `ImageServer` is not running.
  defp maybe_allow_upload(%{assigns: %{load_images?: false}} = socket, _key) do
    socket
  end

  @spec friendly_upload_error(atom(), %Phoenix.LiveView.UploadConfig{}) ::
          String.t()
  defp friendly_upload_error(:not_accepted, %{accept: exts} = _uploads) do
    "not one of accepted extensions: " <> String.replace(exts, ",.", ", .")
  end

  defp friendly_upload_error(:too_large, uploads) do
    size_limit = Float.round(uploads.max_file_size / 1_048_576, 2)

    """
    the file is too large; limit: #{round_into_string(size_limit)}
    MB#{if needs_plural_form?(size_limit), do: "s"}
    """
  end

  @spec text_no_assignable_product_types(atom()) ::
          [String.t() | {:safe, list()}]
  defp text_no_assignable_product_types(:new = _action) do
    ["unable to set product type: no ", link_to_product_types()]
  end

  defp text_no_assignable_product_types(:edit = _action) do
    ["Unable to change product type: no ", link_to_product_types(), "."]
  end

  @spec link_to_product_types() :: {:safe, list()}
  defp link_to_product_types() do
    link("assignable product types", ~p"/product_types")
  end
end
