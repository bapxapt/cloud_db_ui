defmodule CloudDbUiWeb.Router do
  use CloudDbUiWeb, :router

  import CloudDbUiWeb.UserAuth

  alias CloudDbUiWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CloudDbUiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CloudDbUiWeb do
    pipe_through [:browser]

    get "/platform", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", CloudDbUiWeb do
  #   pipe_through [:api]
  # end

  if Application.compile_env(:cloud_db_ui, :mock_routes) do
    scope "/mock" do
      pipe_through [:api]

      post "/upload", CloudDbUiWeb.ImageServerMock, :upload
      get "/", CloudDbUiWeb.ImageServerMock, :up?
      get "/files/:file_name", CloudDbUiWeb.ImageServerMock, :download
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development.
  if Application.compile_env(:cloud_db_ui, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [
        :browser,
        :require_authenticated_user,
        :require_authenticated_admin
      ]

      live_dashboard "/dashboard",
        on_mount: [],
        metrics: CloudDbUiWeb.Telemetry

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", CloudDbUiWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_logged_in_user_away,
      on_mount: [{UserAuth, :redirect_if_user_is_authenticated}] do
        live "/register", UserRegistrationLive, :new
        live "/log_in", UserLoginLive, :new
        live "/reset_password", UserForgotPasswordLive, :new
        live "/reset_password/:token", UserResetPasswordLive, :edit
      end

    post "/log_in", UserSessionController, :create
  end

  scope "/", CloudDbUiWeb do
    pipe_through [:browser]

    get "/log_out", UserSessionController, :delete
    delete "/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{UserAuth, :mount_current_user}] do
        live "/confirm_email", UserConfirmationInstructionsLive, :new
        live "/confirm_email/:token", UserConfirmationLive, :edit
      end
  end

  scope "/top_up", CloudDbUiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :top_up,
      on_mount: [{UserAuth, :ensure_non_admin}] do
        live "/", TopUpLive
      end
  end

  scope "/settings", CloudDbUiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :settings,
      on_mount: [{UserAuth, :ensure_authenticated}] do
        live "/", UserSettingsLive, :edit
        live "/confirm_email/:token", UserSettingsLive, :confirm_email
      end
  end

  # Only admins can view, edit or directly create users.
  scope "/users", CloudDbUiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :users,
      on_mount: [{UserAuth, :ensure_admin}] do
        live "/", UserLive.Index, :index
        live "/new", UserLive.Index, :new
        live "/:id", UserLive.Show, :show
        live "/:id/show", UserLive.Show, :redirect
        live "/:id/edit", UserLive.Index, :edit
        live "/:id/show/edit", UserLive.Show, :edit
      end
  end

  # Only admins can view, create or edit product types.
  scope "/product_types", CloudDbUiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :product_types,
      on_mount: [{UserAuth, :ensure_admin}] do
        live "/", ProductTypeLive.Index, :index
        live "/new", ProductTypeLive.Index, :new
        live "/:id", ProductTypeLive.Show, :show
        live "/:id/show", ProductTypeLive.Show, :redirect
        live "/:id/edit", ProductTypeLive.Index, :edit
        live "/:id/show/edit", ProductTypeLive.Show, :edit
      end
  end

  scope "/products", CloudDbUiWeb do
    pipe_through [:browser]

    live_session :products,
      on_mount: [{UserAuth, :mount_current_user}] do
        # Only admins can create and edit products.
        live "/new", ProductLive.Index, :new
        live "/:id/edit", ProductLive.Index, :edit
        live "/:id/show/edit", ProductLive.Show, :edit
        # Anyone can view products.
        live "/", ProductLive.Index, :index
        live "/:id", ProductLive.Show, :show
        live "/:id/show", ProductLive.Show, :redirect
      end
  end

  scope "/orders", CloudDbUiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :orders,
      on_mount: [{UserAuth, :ensure_authenticated}] do
        # Only admins can directly create or directly edit orders.
        live "/new", OrderLive.Index, :new
        live "/:id/edit", OrderLive.Index, :edit
        live "/:id/show/edit", OrderLive.Show, :edit
        # Any logged-in user can view orders or change sub-order quantity.
        live "/", OrderLive.Index, :index
        live "/:id", OrderLive.Show, :show
        live "/:id/show", OrderLive.Show, :redirect
        live "/:id/pay", OrderLive.Index, :pay
        live "/:id/show/:s_id/edit", OrderLive.Show, :edit_suborder
        live "/:id/show/pay", OrderLive.Show, :pay
      end
  end

  scope "/sub-orders", CloudDbUiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :suborders,
      on_mount: [{UserAuth, :ensure_admin}] do
        # Only admins can directly create or directly edit sub-orders.
        live "/", SubOrderLive.Index, :index
        live "/new", SubOrderLive.Index, :new
        live "/:id", SubOrderLive.Show, :show
        live "/:id/show", SubOrderLive.Show, :redirect
        live "/:id/edit", SubOrderLive.Index, :edit
        live "/:id/show/edit", SubOrderLive.Show, :edit
      end
  end

  scope "/", CloudDbUiWeb do
    pipe_through [:browser]

    live_session :other,
      on_mount: [{UserAuth, :mount_current_user}] do
        live "/", ProductLive.Index, :to_index
        # The module has to be named `ErrorController`:
        # the templates then will be looked for in `ErrorHTML`.
        get "/*rest", ErrorController, :not_found
      end
  end
end
