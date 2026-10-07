# Answers "can this process reach its two stores right now?"
module HealthCheck
  module_function

  def mysql?
    ping_mysql
    true
  rescue StandardError
    false
  end

  def redis?
    ping_redis == "PONG"
  rescue StandardError
    false
  end

  def ping_mysql
    ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") }
  end

  def ping_redis
    AppRedis.with(&:ping)
  end
end
