# Per-address limits. The per-user cooldown lives in Redis next to the board;
# these stop one address from creating many guests to get around it.
Rack::Attack.enabled = !Rails.env.test? && ENV["RATE_LIMIT_DISABLED"] != "1"

Rack::Attack.cache.store =
  if Rails.env.test?
    ActiveSupport::Cache::MemoryStore.new
  else
    ActiveSupport::Cache::RedisCacheStore.new(url: AppRedis.url, namespace: "rack_attack")
  end

placements_per_10s = ENV.fetch("PLACEMENTS_PER_IP_PER_10S", 30).to_i
new_sessions_per_minute = ENV.fetch("NEW_SESSIONS_PER_IP_PER_MINUTE", 20).to_i

Rack::Attack.throttle("placements/ip", limit: placements_per_10s, period: 10) do |request|
  request.ip if request.post? && request.path == "/api/pixels"
end

Rack::Attack.throttle("new_sessions/ip", limit: new_sessions_per_minute, period: 60) do |request|
  request.ip if request.get? && request.path == "/api/session" && request.cookies["guest_token"].to_s.empty?
end

Rack::Attack.throttled_responder = lambda do |request|
  match = request.env["rack.attack.match_data"] || {}
  period = match.fetch(:period, 1).to_i
  retry_after = period - (match.fetch(:epoch_time, Time.now.to_i).to_i % period)
  body = { error: "rate_limited", retry_after_ms: retry_after * 1000 }.to_json

  [429, { "content-type" => "application/json", "retry-after" => retry_after.to_s }, [body]]
end
