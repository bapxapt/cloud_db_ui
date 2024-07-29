defmodule CloudDbUi.StringQueue do
  @moduledoc """
  A module for reducing the number of unique constraint check
  requests to the data base.

  It makes use of a `:queue` in the socket to store a collection
  of "already taken" values. They should be added to this collection
  after a unique constraint error occurs.
  """

  alias CloudDbUiWeb.Utilities
  alias Phoenix.LiveView.Socket
  alias Ecto.Changeset

  import CloudDbUi.Changeset

  @doc """
  Assign a new queue to the `socket` under the `queue_key`.
  """
  @spec assign_queue(%Socket{}, atom(), list()) :: %Socket{}
  def assign_queue(socket, queue_key, values \\ []) do
    Phoenix.Component.assign(socket, queue_key, :queue.from_list(values))
  end

  @doc """
  Add a `value` to the `socket.assigns[queue_key]` queue, removing
  an existing element if the queue grows too large. Does not allow
  duplcates.
  """
  @spec add_to_queue(%Socket{}, atom(), String.t(), pos_integer()) ::
          %Socket{}
  def add_to_queue(socket, queue_key, value, limit) when limit > 0 do
    if in_queue?(socket.assigns[queue_key], value) do
      socket
    else
      queue_new =
        case :queue.len(socket.assigns[queue_key]) < limit do
          true -> socket.assigns[queue_key]
          false -> :queue.drop(socket.assigns[queue_key])
        end

      Phoenix.Component.assign(
        socket,
        queue_key,
        :queue.in(Utilities.trim_downcase(value), queue_new)
      )
    end
  end

  @doc """
  Determine whether a trimmed and down-cased `value`
  is in the `socket.assigns[queue_key]` string queue.
  """
  @spec in_queue?(:queue.queue(), String.t() | nil) :: boolean()
  def in_queue?(queue, value) do
    "#{value}"
    |> Utilities.trim_downcase()
    |> :queue.member(queue)
  end

  @doc """
  Add `changeset.changes[field]` to the `socket.assigns[q_key]` queue,
  if both conditions are true:

    - the `changeset` has a change for the `field`;
    - the `changeset` has an unique constraint error corresponding
      to the `field`.
  """
  @spec maybe_add_taken(
          %Socket{},
          atom(),
          %Changeset{},
          atom(),
          pos_integer()
        ) :: %Socket{}
  def maybe_add_taken(%Socket{} = socket, q_key, changeset, field, limit) do
    cond do
      !Map.has_key?(changeset.changes, field) -> socket
      !has_error?(changeset, field, :unsafe_unique) -> socket
      true -> add_to_queue(socket, q_key, changeset.changes[field], limit)
    end
  end
end
