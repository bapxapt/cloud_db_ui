defmodule CloudDbUiWeb.OrderLive.PayComponent do
  use CloudDbUiWeb, :live_component
  use CloudDbUiWeb.FlashTimed, :live_component

  alias CloudDbUi.{Orders, Accounts}
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket
  alias Ecto.Changeset

  import CloudDbUiWeb.{Utilities, JavaScript, HTML}

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.header>
        <%= @title %>
        <:subtitle></:subtitle>
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

      <.list>
        <:item title="Total">
          PLN <%= format(@order.total) %>
        </:item>
        <:item title="Your balance">
          PLN <%= format(@user.balance) %>
        </:item>
        <:item title="Balance after payment">
          PLN <%= format(Decimal.sub(@user.balance, @order.total)) %>
        </:item>
      </.list>

      <.simple_form
        for={@form}
        id="form-order-payment"
        phx-target={@myself}
        phx-submit={js_push_pay()}
        phx-value-paid="true"
      >
        <.error :if={@error_text}><%= @error_text %></.error>

        <:actions>
          <.button phx-disable-with="Paying...">
            Pay
          </.button>
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
      |> assign_new(
        :form,
        fn -> to_form(Orders.payment_changeset(order)) end
      )
      |> assign_error_text()

    {:ok, socket_new}
  end

  @impl true
  def handle_event("pay", %{"paid" => "true"} = _params, socket) do
    {:noreply, pay_for_order(socket)}
  end

  # An attempt to pay for an unpaid order when there is an error.
  @spec pay_for_order(%Socket{}) :: %Socket{}
  defp pay_for_order(%{assigns: %{error_text: text}} = socket)
       when not is_nil(text) do
    FlashTimed.put(socket, :error, String.capitalize(text) <> ".", __MODULE__)
  end

  # No `:error_text` in `socket.assigns`.
  defp pay_for_order(%{assigns: %{order: %{paid_at: nil}}} = socket
       ) do
    balance =
      socket.assigns.user.balance
      |> Decimal.sub(socket.assigns.order.total)
      |> Decimal.round(2)

    pay_for_order(
      socket,
      Accounts.payment_changeset(socket.assigns.user, %{"balance" => balance}),
      Orders.payment_changeset(socket.assigns.order)
    )
  end

  @spec pay_for_order(%Socket{}, %Changeset{}, %Changeset{}) :: %Socket{}
  defp pay_for_order(socket, %Changeset{} = set_user, %Changeset{} = set_order)
       when set_user.valid? and set_order.valid? do
    {:ok, order_updated} = Orders.pay_for_order(set_order)
    {:ok, user_updated} = Accounts.spend_user_balance(set_user)

    notify_parent({:saved, order_updated, true})
    notify_parent({:put_flash, :info, order_paid_message(order_updated)})

    socket
    |> js_set_text("#user-balance", "PLN #{user_updated.balance}")
    |> push_patch([to: socket.assigns.patch])
  end

  # Any invalid changeset (or both).
  defp pay_for_order(socket, %Changeset{}, %Changeset{} = set_order) do
    assign(socket, :form, to_form(set_order))
  end

  @spec order_paid_message(%Order{}) :: [String.t() | {:safe, list()}]
  defp order_paid_message(order) do
    [
      "Successfully paid for the ",
      link("order ID #{order.id}", ~p"/orders/#{order.id}"),
      "."
    ]
  end

  @spec assign_error_text(%Socket{}) :: %Socket{}
  defp assign_error_text(socket) do
    assign(socket, :error_text, error_text(socket))
  end

  @spec error_text(%Socket{}) :: String.t() | nil
  defp error_text(%{assigns: %{user: user, order: order}}) do
    cond do
      !sufficient_balance?(user, order) -> "insufficient funds"
      length(order.suborders) == 0 -> "no order positions"
      true -> nil
    end
  end

  @spec sufficient_balance?(%User{}, %Order{}) :: boolean()
  defp sufficient_balance?(user, order) do
    Decimal.compare(user.balance, order.total) != :lt
  end

  # Sends the "pay" event to be handled by this component
  # and unhides `"#flash"` if it has been closed (hidden).
  @spec js_push_pay() :: %JS{}
  defp js_push_pay() do
    "pay"
    |> JS.push()
    |> JS.remove_attribute("style", [to: "#flash"])
  end
end
