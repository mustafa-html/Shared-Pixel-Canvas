require "rails_helper"

RSpec.describe "GET /health" do
  it "is healthy when MySQL and Redis answer" do
    get "/health"

    expect(response).to have_http_status(:ok)
    expect(json).to eq("status" => "ok", "checks" => { "mysql" => true, "redis" => true })
  end

  it "returns 503 when Redis is unreachable" do
    allow(HealthCheck).to receive(:ping_redis).and_raise(Redis::CannotConnectError)

    get "/health"

    expect(response).to have_http_status(:service_unavailable)
    expect(json["checks"]).to eq("mysql" => true, "redis" => false)
  end

  it "returns 503 when MySQL is unreachable" do
    allow(HealthCheck).to receive(:ping_mysql).and_raise(ActiveRecord::ConnectionNotEstablished)

    get "/health"

    expect(response).to have_http_status(:service_unavailable)
    expect(json["checks"]).to eq("mysql" => false, "redis" => true)
  end
end
