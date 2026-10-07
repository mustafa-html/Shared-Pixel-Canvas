class HealthController < ApplicationController
  def show
    checks = { mysql: HealthCheck.mysql?, redis: HealthCheck.redis? }
    healthy = checks.values.all?

    render json: { status: healthy ? "ok" : "unavailable", checks: },
           status: healthy ? :ok : :service_unavailable
  end
end
