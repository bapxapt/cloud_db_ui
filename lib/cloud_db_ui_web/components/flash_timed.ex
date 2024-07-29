defmodule CloudDbUiWeb.FlashTimed do
  alias Phoenix.LiveView.Socket

  @type flash() :: %{String.t() => String.t()}
  @type flash_title() :: String.t() | [String.t()]

  @doc """
  Put a flash, then send a signal to clear it in `timer` milliseconds.
  A cancellable reference is stored in `socket.assigns.flash_clear_refs`.
  """
  @spec put(%Socket{}, atom(), flash_title()) :: %Socket{}
  def put(%Socket{} = socket, kind, title), do: put(socket, kind, title, 5000)

  # For a `:controller`.
  @spec put(%Plug.Conn{}, atom(), flash_title()) :: %Plug.Conn{}
  def put(%Plug.Conn{} = conn, kind, title), do: put(conn, kind, title, 5000)

  @spec put(%Plug.Conn{}, atom(), flash_title(), non_neg_integer()) ::
          %Plug.Conn{}
  def put(%Plug.Conn{} = conn, kind, title, timer) when is_integer(timer) do
    conn
    # TODO: |> maybe_cancel_timer(kind)
    |> Phoenix.Controller.put_flash(kind, title)
    # TODO: |> assign_flash_clear_refs(kind, ref(kind, timer))
  end

  # For a `:live_view`.
  @spec put(%Socket{}, atom(), flash_title(), non_neg_integer()) :: %Socket{}
  def put(%Socket{} = socket, kind, title, timer) when is_integer(timer) do
    socket
    |> maybe_cancel_timer(kind)
    |> Phoenix.LiveView.put_flash(kind, title)
    |> assign_flash_clear_refs(kind, ref(kind, timer))
  end

  # For a `:live_component`.
  @spec put(%Socket{}, atom(), flash_title(), module()) :: %Socket{}
  def put(%Socket{assigns: %{id: _}} = socket, key, title, module) do
    put(socket, key, title, module, 5000)
  end

  @spec put(%Socket{}, atom(), flash_title(), module(), non_neg_integer()) ::
          %Socket{}
  def put(%Socket{assigns: %{id: id}} = socket, kind, title, module, timer) do
    socket
    |> maybe_cancel_timer(kind)
    |> Phoenix.LiveView.put_flash(kind, title)
    |> assign_flash_clear_refs(kind, ref(id, kind, module, timer))
  end

  @doc """
  Set delayed clear references for flashes in `socket.assigns`.
  This allows (in `mount()`) to clear flashes that, for example,
  have been set before `push_patch()`:

    socket
    |> FlashTimed.put(:error, "No access.")
    |> push_patch([to: ~p"/safe"])

  There will be no flash clear reference for this flash at `/safe`.
  """
  @spec clear_after(%Socket{}) :: %Socket{}
  def clear_after(socket), do: clear_after(socket, 5000)

  @spec clear_after(%Socket{}, non_neg_integer()) :: %Socket{}
  def clear_after(%{assigns: %{flash: flash}} = socket, timer) when flash != %{} do
    socket.assigns.flash
    |> Map.keys()
    |> Enum.reduce(socket, fn kind, acc ->
      assign_flash_clear_refs(acc, kind, ref(kind, timer))
    end)
  end

  # No flashes in `socket.assigns`.
  def clear_after(%Socket{} = socket, _timer), do: socket

  @doc """
  Clear a flash and remove its reference from `:flash_clear_refs`.
  """
  @spec clear(%Socket{}, atom()) :: %Socket{}
  def clear(%Socket{assigns: %{flash_clear_refs: _refs}} = socket, kind) do
    socket
    |> Phoenix.Component.update(:flash_clear_refs, &Map.delete(&1, kind))
    |> Phoenix.LiveView.clear_flash(kind)
  end

  # TODO: remove if a better way is found
    # TODO: (Phoenix.LiveView.send_update_after(module, %{id: id, clear_flash: kind}, 0)
    # TODO: via some JS event in CoreComponents)
  # `socket.assigns` do not contain `:flash_clear_refs`, do not clear.
  def clear(%Socket{} = socket, _kind), do: socket

  @doc """
  Get the type (`:info` or `:error`) of a first encountered flash message.
  """
  @spec kind(flash()) :: atom()
  def kind(flash) do
    Map.to_list(flash)
    |> hd()
    |> elem(0)
    |> String.to_existing_atom()
  end

  @doc """
  Get the text (title) of a first encountered flash message.
  """
  @spec title(flash()) :: String.t()
  def title(flash) when is_map(flash) do
    flash
    |> kind()
    |> title()
  end

  @spec title(atom()) :: String.t()
  def title(:info), do: "Success!"

  def title(:error), do: "Error!"

  @doc """
  For a `:live_view`:

    - Inject `handle_info()` functions to handle flash-related
    messages from itself and from its child components.

  For a `:live_component`:

    - Inject an `update()` function to clear flash-related messages.
  """
  defmacro __using__(:live_view) do
    quote do
      @impl true
      def handle_info({:clear_flash, kind}, socket) do
        {:noreply, CloudDbUiWeb.FlashTimed.clear(socket, kind)}
      end

      def handle_info({_module, {:put_flash, kind, title}}, socket) do
        {:noreply, CloudDbUiWeb.FlashTimed.put(socket, kind, title)}
      end
    end
  end

  # Inject an `update()` function needed by a live component to clear
  # flash-related messages.
  defmacro __using__(:live_component) do
    quote do
      @impl true
      def update(%{clear_flash: kind} = assigns, socket) do
        socket_new =
          socket
          |> assign(assigns)
          |> CloudDbUiWeb.FlashTimed.clear(kind)

        {:ok, socket_new}
      end
    end
  end

  # Cancel the previous flash clearing timer.
  @spec maybe_cancel_timer(%Socket{}, atom()) :: %Socket{}
  defp maybe_cancel_timer(%{assigns: %{flash_clear_refs: refs}} = socket, key)
       when refs != nil do
    if refs[key] do
      Process.cancel_timer(refs[key])
    end

    socket
  end

  # `socket.assigns` do not contain `:flash_clear_refs`,
  # or `socket.assigns.flash_clear_refs == nil`
  defp maybe_cancel_timer(socket, _key), do: socket

  @spec assign_flash_clear_refs(%Socket{}, atom(), reference()) :: %Socket{}
  defp assign_flash_clear_refs(%Socket{} = socket, kind, ref_new) do
    Phoenix.Component.assign(
      socket,
      :flash_clear_refs,
      put_flash_clear_ref(socket, kind, ref_new)
    )
  end

  # Return a `%{kind => flash_timer_clear_reference}` map.
  @spec put_flash_clear_ref(%Socket{}, atom(), reference()) ::
          %{atom() => reference()}
  defp put_flash_clear_ref(%Socket{} = socket, kind, ref_new) do
    socket.assigns
    |> Map.get(:flash_clear_refs, %{})
    |> Map.put(kind, ref_new)
  end

  # Return a reference that allows to cancel the timer.
  # For a `:live_view`.
  @spec ref(atom(), non_neg_integer()) :: reference()
  defp ref(kind, timer) do
    Process.send_after(self(), {:clear_flash, kind}, timer)
  end

  # For a `:live_component`.
  @spec ref(String.t(), atom(), module(), non_neg_integer()) :: reference()
  defp ref(id, kind, module, timer) do
    Phoenix.LiveView.send_update_after(
      module,
      %{id: id, clear_flash: kind},
      timer
    )
  end
end
