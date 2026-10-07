require "rails_helper"

RSpec.describe "Per-address rate limits" do
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.enabled = false
  end

  def limit_for(name)
    Rack::Attack.throttles.fetch(name).limit
  end

  it "stops an address that keeps posting placements" do
    start_session
    limit = limit_for("placements/ip")

    limit.times { post_pixel(0, 0, 1) }
    expect(response).to have_http_status(:too_many_requests)
    expect(json["error"]).to eq("cooldown")

    post_pixel(0, 0, 1)
    expect(response).to have_http_status(:too_many_requests)
    expect(json["error"]).to eq("rate_limited")
    expect(json["retry_after_ms"]).to be_between(1000, 10_000)
    expect(response.headers["Retry-After"].to_i).to be_between(1, 10)
  end

  it "stops an address that keeps creating new guests, but not a returning visitor" do
    limit = limit_for("new_sessions/ip")

    limit.times do
      get "/api/session"
      cookies.delete("guest_token")
    end
    expect(response).to have_http_status(:ok)

    get "/api/session"
    expect(response).to have_http_status(:too_many_requests)

    cookies[:guest_token] = "anything-at-all"
    get "/api/session"
    expect(response).to have_http_status(:ok)
  end
end
