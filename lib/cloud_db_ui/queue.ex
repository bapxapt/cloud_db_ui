defmodule CloudDbUi.Queue do
  @moduledoc """
  A module for reducing the number of unique constraint check
  requests to the data base.

  It makes use of a `:queue` in the socket to store a collection
  of "already taken" values. They should be added to this collection
  after a unique constraint error occurs.
  """

  alias CloudDbUiWeb.Utilities
  alias Phoenix.LiveView.Socket

  @doc """
  Assign a new queue to the `socket` under a `key`.
  """
  @spec assign_queue(%Socket{}, atom(), list()) :: %Socket{}
  def assign_queue(socket, key, values \\ []) do
    Phoenix.Component.assign(socket, key, :queue.from_list(values))
  end

  @doc """
  Add a `value` to the `socket.assigns[key]` queue, removing
  an existing element if the queue grows too large. Does not
  allow duplcates.
  """
  @spec add_to_queue(%Socket{}, atom(), String.t(), non_neg_integer()) ::
          %Socket{}
  def add_to_queue(%Socket{} = socket, key, value, limit) do
    if in_queue?(socket, key, value) do
      socket
    else
      queue_new =
        case :queue.len(socket.assigns[key]) < limit do
          true -> socket.assigns[key]
          false -> :queue.drop(socket.assigns[key])
        end

      Phoenix.Component.assign(
        socket,
        key,
        :queue.in(Utilities.trim_downcase(value), queue_new)
      )
    end
  end

  @doc """
  Determine whether a `value` is in the `socket.assigns[key]` queue.
  """
  @spec in_queue?(%Socket{}, atom(), String.t()) :: boolean()
  def in_queue?(%Socket{} = socket, key, value) do
    :queue.member(Utilities.trim_downcase(value), socket.assigns[key])
  end
end
