defmodule CloudDbUiWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use CloudDbUiWeb, :controller
      use CloudDbUiWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  @spec __using__(atom()) :: Macro.t()
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  @spec static_paths() :: [String.t()]
  def static_paths(), do: ~w(assets fonts images favicon.ico robots.txt)

  @spec router() :: {atom(), list(), list()}
  def router() do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  # @spec channel() :: {atom(), list(), list()}
  # def channel() do
  #   quote do
  #     use Phoenix.Channel
  #   end
  # end

  @spec controller() :: {atom(), list(), list()}
  def controller() do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: CloudDbUiWeb.Layouts]

      import Plug.Conn
      import CloudDbUiWeb.Gettext

      unquote(verified_routes())
    end
  end

  @spec live_view() :: {atom(), list(), list()}
  def live_view() do
    quote do
      use Phoenix.LiveView,
        layout: {CloudDbUiWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @spec live_component() :: {atom(), list(), list()}
  def live_component() do
    quote do
      use Phoenix.LiveComponent

      alias Phoenix.LiveView.Socket

      unquote(html_helpers())

      @spec notify_parent(any()) :: any()
      defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
    end
  end

  @spec html() :: {atom(), list(), list()}
  def html() do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        [only: [get_csrf_token: 0, view_module: 1, view_template: 1]]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  @spec verified_routes() :: {atom(), list(), list()}
  def verified_routes() do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: CloudDbUiWeb.Endpoint,
        router: CloudDbUiWeb.Router,
        statics: CloudDbUiWeb.static_paths()
    end
  end

  @spec html_helpers() :: {atom(), list(), list()}
  defp html_helpers() do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import CloudDbUiWeb.CoreComponents
      import CloudDbUiWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end
end
