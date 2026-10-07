Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true

  # Requests arrive through the Vite proxy and Docker service names.
  config.hosts.clear

  config.active_record.verbose_query_logs = true
  config.log_level = ENV.fetch("LOG_LEVEL", "debug").to_sym
end
