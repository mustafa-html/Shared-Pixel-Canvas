Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # The built React client is copied into public/ by the production image.
  config.public_file_server.enabled = true

  # TLS is terminated by the host's proxy. Set FORCE_SSL=false to run the
  # production image over plain HTTP, for example on a private network.
  config.assume_ssl = true
  config.force_ssl = ENV["FORCE_SSL"] != "false"
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/health" } } }

  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))

  config.active_record.dump_schema_after_migration = false
  config.active_support.report_deprecations = false
end
