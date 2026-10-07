require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

module PixelCanvas
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true
    config.time_zone = "UTC"

    # The guest identity lives in a signed cookie, which API-only apps leave out.
    config.middleware.use ActionDispatch::Cookies

    # The board is 131 KB of mostly repeated bytes, so it compresses well.
    config.middleware.use Rack::Deflater

    config.active_job.queue_adapter = :sidekiq

    # Browsers send no CORS requests here: the client is served from the same
    # origin (Vite proxy in development, Rails in production). WebSocket
    # upgrades are checked against this list, plus the request's own host.
    default_origins = Rails.env.production? ? "" : "http://localhost:5173,http://127.0.0.1:5173"
    config.x.client_origins = ENV.fetch("CLIENT_ORIGINS", default_origins).split(",").map(&:strip).reject(&:empty?)
    config.action_cable.allowed_request_origins = config.x.client_origins
    config.action_cable.mount_path = nil
  end
end
