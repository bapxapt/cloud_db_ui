defmodule CloudDbUiWeb.Router do
  use CloudDbUiWeb, :router

  import CloudDbUiWeb.UserAuth

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

    live_session :redirect_user_away,
      on_mount: [{CloudDbUiWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", CloudDbUiWeb do
    pipe_through [:browser]

    get "/log_out", UserSessionController, :delete
    get "/users/log_out", UserSessionController, :delete
    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{CloudDbUiWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm", UserConfirmationInstructionsLive, :new
      live "/users/confirm/:token", UserConfirmationLive, :edit
    end
  end

  scope "/", CloudDbUiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :user_settings,
      on_mount: [{CloudDbUiWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end

    live_session :admins,
      on_mount: [{CloudDbUiWeb.UserAuth, :ensure_admin}] do
      # Only admins can create and directly edit orders.
      live "/orders/new", OrderLive.Index, :new
      live "/orders/:id/edit", OrderLive.Index, :edit
      live "/orders/:id/show/edit", OrderLive.Show, :edit
      # Only admins can list, create and edit product types.
      live "/product_types", ProductTypeLive.Index, :index
      live "/product_types/new", ProductTypeLive.Index, :new
      live "/product_types/:id/edit", ProductTypeLive.Index, :edit
      live "/product_types/:id", ProductTypeLive.Show, :show
      live "/product_types/:id/show", ProductTypeLive.Show, :redirect
      live "/product_types/:id/show/edit", ProductTypeLive.Show, :edit
      # Only admins can create and edit products.
      live "/products/new", ProductLive.Index, :new
      live "/products/:id/edit", ProductLive.Index, :edit
      live "/products/:id/show/edit", ProductLive.Show, :edit
      # Only admins can directly create or directly edit sub-orders.
      live "/sub-orders", SubOrderLive.Index, :index
      live "/sub-orders/new", SubOrderLive.Index, :new
      live "/sub-orders/:id/edit", SubOrderLive.Index, :edit
      live "/sub-orders/:id", SubOrderLive.Show, :show
      live "/sub-orders/:id/show", SubOrderLive.Show, :redirect
      live "/sub-orders/:id/show/edit", SubOrderLive.Show, :edit
      # Only admins can directly create and edit users.
      live "/users", UserLive.Index, :index
      live "/users/new", UserLive.Index, :new
      live "/users/:id/edit", UserLive.Index, :edit
      live "/users/:id", UserLive.Show, :show
      live "/users/:id/show", UserLive.Show, :redirect
      live "/users/:id/show/edit", UserLive.Show, :edit
    end

    live_session :users_or_admins,
      on_mount: [{CloudDbUiWeb.UserAuth, :ensure_authenticated}] do
      live "/orders", OrderLive.Index, :index
      live "/orders/:id", OrderLive.Show, :show
      live "/orders/:id/show", OrderLive.Show, :redirect
      live "/orders/:id/pay", OrderLive.Index, :pay
      live "/orders/:id/show/:s_id/edit", OrderLive.Show, :edit_suborder
      live "/orders/:id/show/pay", OrderLive.Show, :pay
    end

    live_session :users,
      on_mount: [{CloudDbUiWeb.UserAuth, :ensure_non_admin}] do
      live "/top_up", TopUpLive
    end
  end

  scope "/", CloudDbUiWeb do
    pipe_through [:browser]

    live_session :admins_users_guests,
      on_mount: [{CloudDbUiWeb.UserAuth, :mount_current_user}] do
      live "/", ProductLive.Index, :to_index
      live "/products", ProductLive.Index, :index
      live "/products/:id", ProductLive.Show, :show
      live "/products/:id/show", ProductLive.Show, :redirect
    end
  end

  scope "/", CloudDbUiWeb do
    pipe_through [:browser]

    live_session :any,
      on_mount: [{CloudDbUiWeb.UserAuth, :mount_current_user}] do
      # The module has to be named `ErrorController`:
      # the templates then will be looked for in `ErrorHTML`.
      get "/*rest", ErrorController, :not_found
    end
  end
end
