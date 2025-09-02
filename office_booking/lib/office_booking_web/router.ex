defmodule OfficeBookingWeb.Router do
  use OfficeBookingWeb, :router

  import OfficeBookingWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OfficeBookingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OfficeBookingWeb do
    pipe_through :browser

    get "/", PageController, :home
    # Public room gallery
  end

   scope "/", OfficeBookingWeb do
    pipe_through [:browser, :require_authenticated_user]
  end


  # Other scopes may use custom stacks.
  # scope "/api", OfficeBookingWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:office_booking, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OfficeBookingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", OfficeBookingWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{OfficeBookingWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit

    end

    post "/users/log_in", UserSessionController, :create
  end

  # File serving routes
  scope "/uploads", OfficeBookingWeb do
    pipe_through :browser

    get "/rooms/:filename", RoomController, :show_photo
  end

  scope "/", OfficeBookingWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{OfficeBookingWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/dashboard", DashboardLive, :index

      # Booking routes
      live "/bookings", BookingLive.Index, :index
      live "/rooms/:room_id/book", BookingLive.New, :new

      # Admin-only room management routes
      live "/rooms", RoomLive.Index, :index
      live "/rooms/new", RoomLive.Index, :new
      live "/rooms/:id/edit", RoomLive.Index, :edit
      live "/rooms/:id", RoomLive.Show, :show
      live "/rooms/:id/show/edit", RoomLive.Show, :edit

      live "/messages", MessageLive.Index, :index
      live "/messages/new", MessageLive.New, :new
      live "/messages/conversation/:user_id", MessageLive.Conversation, :show
      live "/messages/transfer_request", MessageLive.TransferRequest, :new
    end
  end

  scope "/", OfficeBookingWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{OfficeBookingWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new

      live "/gallery", RoomLive.Gallery, :index
      live "/gallery/:id", RoomLive.Gallery, :show

      live "/bookings/new", BookingLive.Index, :new
      live "/bookings/:id/edit", BookingLive.Index, :edit
      live "/bookings/:id", BookingLive.Show, :show
      live "/bookings/:id/show/edit", BookingLive.Show, :edit
      live "/bookings", BookingLive.Index, :index

    end
  end
end
