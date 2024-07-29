defmodule CloudDbUiWeb.OrderLive.FormComponent do
  use CloudDbUiWeb, :live_component

  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias Phoenix.LiveView.Socket

  import CloudDbUiWeb.Utilities

  @type params() :: CloudDbUi.Type.params()

  # TODO: do not clear a user ID error unless user ID receives another change
    # TODO: and this change is not just adding a space or changing the case of a letter

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
        id="order-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:user_id]}
          type="text"
          label={label_user_id(@fetched_user)}
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
    |> assign(:fetched_user, user)
    |> assign(:form, to_form(changeset, [action: :validate]))
  end

  @spec save_order(%Socket{}, atom(), params()) :: %Socket{}
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

    notify_parent({:saved, order_new})
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

  # Get a user from the data base, unless:
  #
  #   - trimmed `order_params["user_id"]` is neither a valid ID
  #     nor a valid e-mail (return `nil`);
  #   - `order_params["user_id"]` differs
  #     from `form.params["user_id"]` (a previous value
  #     of the user ID input field) only by spaces (return whatever
  #     `:fetched_user` is in `socket.assigns`, even if `nil`);
  #   -`socket.assigns.fetched_user != nil`, and trimmed
  #     `order_params["user_id"]` matches either the ID or the e-mail
  #     of the `:fetched_user` (return `socket.assigns.fetched_user`);
  #   - `order.user != nil`, and trimmed `order_params["user_id"]`
  #     matches the ID or the e-mail of that `:user` (return `order.user`).
  @spec maybe_get_user(%Socket{}, params()) :: %User{} | nil
  defp maybe_get_user(
         %{assigns: %{order: order, fetched_user: user, form: form}},
         %{"user_id" => id_or_email} = _order_params
       ) do
    trimmed = String.trim(id_or_email)

    cond do
      !valid_id?(trimmed) and !User.valid_email?(trimmed) -> nil
      trimmed == trim(form.params["user_id"]) -> user
      user && (trimmed == "#{user.id}" or trimmed == user.email) -> user
      order.user && trimmed == "#{order.user.id}" -> order.user
      order.user && trimmed == "#{order.user.email}" -> order.user
      true -> Accounts.get_user_by_id_or_email(trimmed)
    end
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

  # `fetched_user` is a `%User{}` found in the data base after
  # inputting a user ID or a user e-mail.
  @spec label_user_id(%User{} | nil) :: String.t()
  defp label_user_id(nil = _fetched_user), do: "User ID or e-mail address"

  defp label_user_id(%User{} = fetched_user) do
    "User ID (#{fetched_user.id}) or e-mail address (#{fetched_user.email})"
  end

  @spec notify_parent(any()) :: any()
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
