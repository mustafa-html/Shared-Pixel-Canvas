Sidekiq.configure_server do |config|
  config.redis = { url: AppRedis.url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: AppRedis.url }
end
