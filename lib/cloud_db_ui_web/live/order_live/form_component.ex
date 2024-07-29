defmodule CloudDbUiWeb.OrderLive.FormComponent do
  use CloudDbUiWeb, :live_component

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias Phoenix.LiveView.Socket
  alias Phoenix.HTML.Form

  import CloudDbUiWeb.{Utilities, Form}

  @type params() :: CloudDbUi.Type.params()
  @type errors() :: CloudDbUi.Type.errors()

  # TODO: maybe keep a queue of {id_email, error | nil}?

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
        id="order-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:user_id]}
          type="text"
          label={label_user_id(@fetched_user, @form)}
          phx-debounce="blur"
        />

        <.list>
          <:item title="Total"><%= format(@form[:total].value) %></:item>
        </.list>

        <.input
          field={@form[:paid]}
          type="checkbox"
          label="Paid"
        />
        <.input
          disabled={@form[:paid].value not in [true, "true"]}
          field={@form[:paid_at]}
          type="datetime-local"
          label="Payment date and time (UTC)"
        />

        <:actions>
          <.button phx-disable-with="Saving...">Save order</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(socket), do: {:ok, socket}

  @impl true
  def update(%{order: order} = assigns, socket) do
    socket_new =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(Orders.change_order(order)) end)
      |> assign(:fetched_user, order.user)

    {:ok, socket_new}
  end

  @impl true
  def handle_event("validate", %{"order" => order_params}, socket) do
    {:noreply, validate_order(socket, order_params)}
  end

  def handle_event("save", %{"order" => order_params}, socket) do
    {:noreply, save_order(socket, socket.assigns.action, order_params)}
  end

  @spec validate_order(%Socket{}, params()) :: %Socket{}
  defp validate_order(%{assigns: %{order: order}} = socket, order_params) do
    user = maybe_get_user(socket, order_params)

    changeset =
      Orders.change_order(
        order,
        maybe_put_paid_at(order_params, socket),
        user
      )

    socket
    |> maybe_assign_fetched_user(user)
    |> assign(:form, to_form(changeset, [action: :validate]))
  end

  # Any input field has any error. This is needed to prevent
  # saving with a "user not found" error (because the `:fetched_user`
  # would not get replaced with a `nil`).
  @spec save_order(%Socket{}, atom(), params()) :: %Socket{}
  defp save_order(socket, _action, _p) when socket.assigns.form.errors != [] do
    socket
  end

  defp save_order(%{assigns: %{order: order}} = socket, :edit, order_params) do
    order
    |> Orders.update_order(order_params, socket.assigns.fetched_user)
    |> handle_saving_result(
      socket,
      "Order ID #{order.id} updated successfully."
    )
  end

  defp save_order(socket, :new, order_params) do
    order_params
    |> Orders.create_order(socket.assigns.fetched_user)
    |> handle_saving_result(socket, "Order created successfully.")
  end

  # Success.
  @spec handle_saving_result({:ok, %Order{}}, %Socket{}, String.t()) ::
          %Socket{}
  defp handle_saving_result({:ok, order}, socket, flash_msg) do
    order_new =
      order
      |> Map.replace!(:user, socket.assigns.fetched_user)
      |> Map.replace!(:suborders, socket.assigns.order.suborders)

    case socket.assigns.action do
      :new ->
        notify_parent({:saved, order_new, true})

      :edit ->
        refilter? =
          CloudDbUiWeb.Flop.refilter?(
            socket.assigns.order,
            order_new,
            [:user_id, :paid, :paid_at]
          )

        notify_parent({:saved, order_new, refilter?})
    end

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

  # Get a user from the data base, unless:
  #
  #   - `id_mail` is neither a valid ID nor a valid e-mail (return `nil`);
  #   -`socket.assigns.fetched_user != nil`, and `id_mail` matches
  #     either the ID or the e-mail of the `:fetched_user` (return
  #     `socket.assigns.fetched_user`);
  #   - `order.user != nil`, and `id_mail` matches the ID
  #     or the e-mail of that `:user` (return `order.user`);
  #   - `id_mail` differs from `form.params["user_id"]` (a previous
  #     value of the user ID input field) only by whitespaces and/or
  #     by letter case changes (return `nil`).
  @spec maybe_get_user(%Socket{}, params()) :: %User{} | nil
  defp maybe_get_user(
         %{assigns: %{order: order, fetched_user: user, form: form}},
         %{"user_id" => id_or_email_untrimmed} = _order_params
       ) do
    id_mail = trim_downcase(id_or_email_untrimmed)

    cond do
      !valid_id?(id_mail) and !User.valid_email?(id_mail) -> nil
      User.match_id_or_email?(id_mail, user) -> user
      User.match_id_or_email?(id_mail, order.user) -> order.user
      !significant_change?(id_mail, form.params["user_id"]) -> nil
      true -> Accounts.get_user_by_id_or_email(id_mail)
    end
  end

  # Do not replace an existing value of `:fetched_user` with `nil`.
  # Also do not replace if it is
  @spec maybe_assign_fetched_user(%Socket{}, %User{} | nil) :: %Socket{}
  defp maybe_assign_fetched_user(socket, nil), do: socket

  defp maybe_assign_fetched_user(socket, user) do
    assign(socket, :fetched_user, user)
  end

  # Replace the value of `"paid_at"` in `order_params` if the "Paid"
  # check box has just been checked (the previous state saved in
  # `form.params` is not equal to the current `"true"` state).
  # This helps to avoid clearing the "Payment date and time (UTC)"
  # input field every time the "Paid" check box gets checked.
  @spec maybe_put_paid_at(params(), %Socket{}) :: params()
  defp maybe_put_paid_at(order_params, %Socket{assigns: %{form: form}}) do
    cond do
      order_params["paid"] != "true" -> order_params
      form.params["paid"] == order_params["paid"] -> order_params
      true -> Map.put(order_params, "paid_at", form.params["paid_at"])
    end
  end

  # `user` (`:fetched_user`) has been fetched from the data base
  # after inputting a user ID or a user e-mail.
  @spec label_user_id(%User{} | nil, %Form{}) :: String.t()
  defp label_user_id(user, %Form{} = form) do
    label_user_id(
      user,
      has_error?(form, :user_id, [:user_id_not_admin], :exclude)
    )
  end

  # A non-`nil` `user`, and no `:user_id` error (or only an error
  # with `validation: :user_id_not_admin`).
  @spec label_user_id(%User{} | nil, boolean()) :: String.t()
  defp label_user_id(%User{} = user, false = _error_exists?) do
    "User ID (#{user.id}) or e-mail address (#{user.email})"
  end

  # A `nil` `user`, and/or a `:user_id` error that has a `:validation`
  # different from `:user_id_not_admin`.
  defp label_user_id(_user, _error_exists?), do: "User ID or e-mail address"
end
