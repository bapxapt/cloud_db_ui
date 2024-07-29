defmodule CloudDbUiWeb.OrderLive.PayComponent do
  use CloudDbUiWeb, :live_component
  use CloudDbUiWeb.FlashTimed, :live_component

  alias CloudDbUi.Orders
  alias CloudDbUi.Orders.Order
  alias CloudDbUi.Accounts
  alias CloudDbUi.Accounts.User
  alias CloudDbUiWeb.FlashTimed
  alias Phoenix.LiveView.Socket
  alias Ecto.Changeset

  import CloudDbUiWeb.Utilities
  import CloudDbUiWeb.JavaScript
  import CloudDbUiWeb.HTML

  @type params() :: CloudDbUi.Type.params()

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle></:subtitle>
      </.header>

      <.flash
        id="flash"
        :if={@flash != %{}}
        flash={@flash}
        kind={FlashTimed.kind(@flash)}
        title={FlashTimed.title(@flash)}
      >
        <%= Map.values(@flash) |> hd() %>
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

      <.error :if={insufficient_balance?(@user, @order)}>
        insufficient funds
      </.error>

      <.simple_form
        for={@form}
        id="order-payment-form"
        phx-target={@myself}
        phx-submit={js_push_pay()}
        phx-value-paid="true"
      >
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
      |> assign_new(:form, fn -> to_form(Orders.pay_for_order(order)) end)

    {:ok, socket_new}
  end

  @impl true
  def handle_event("pay", %{"paid" => "true"} = params, socket) do
    {:noreply, pay_for_order(socket, params)}
  end

  # An attempt to pay for an unpaid order.
  @spec pay_for_order(%Socket{}, params()) :: %Socket{}
  defp pay_for_order(
         %{assigns: %{user: user, order: %{paid_at: nil} = order}} = socket,
         params
       ) do
    if Decimal.compare(user.balance, order.total) == :lt do
      FlashTimed.put(socket, :error, "Insufficient funds.", __MODULE__)
    else
      balance_new =
        user.balance
        |> Decimal.sub(order.total)
        |> Decimal.round(2)

      pay_for_order(
        socket,
        Accounts.payment_changeset(user, %{"balance" => balance_new}),
        Orders.payment_changeset(order, params)
      )
    end
  end

  @spec pay_for_order(%Socket{}, %Changeset{}, %Changeset{}) :: %Socket{}
  defp pay_for_order(socket, %Changeset{} = set_user, %Changeset{} = set_order)
       when set_user.valid? == true and set_order.valid? == true do
    {:ok, order_updated} = Orders.pay_for_order(set_order)
    {:ok, user_updated} = Accounts.spend_user_balance(set_user)

    notify_parent({:saved, order_updated})
    notify_parent({:put_flash, :info, order_paid_message(order_updated)})

    socket
    |> js_set_text("#user-balance", "PLN #{user_updated.balance}")
    |> push_patch([to: socket.assigns.patch])
  end

  # Any changeset is invalid.
  defp pay_for_order(socket, %Changeset{} = _, %Changeset{} = set_order) do
    assign(socket, form: to_form(set_order))
  end

  @spec order_paid_message(%Order{}) :: [String.t() | {:safe, list()}]
  defp order_paid_message(order) do
    [
      "Successfully paid for the ",
      link("order ID #{order.id}", ~p"/orders/#{order.id}"),
      "."
    ]
  end

  @spec insufficient_balance?(%User{}, %Order{}) :: boolean()
  defp insufficient_balance?(user, order) do
    user.balance
    |> Decimal.sub(order.total)
    |> Decimal.round(2)
    |> Decimal.compare(0)
    |> Kernel.==(:lt)
  end

  # Sends the "pay" event to be handled by this component
  # and unhides `"#flash"` if it has been closed.
  @spec js_push_pay() :: %JS{}
  defp js_push_pay() do
    JS.push("pay")
    |> JS.remove_attribute("style", [to: "#flash"])
  end

  @spec notify_parent(any()) :: any()
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
