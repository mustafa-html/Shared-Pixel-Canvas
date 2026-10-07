require "connection_pool"
require "uri"

# One pool of Redis connections for the board, shared by every Puma thread.
module AppRedis
  TEST_DATABASE = "/1".freeze

  # The test suite empties its Redis database before every example, so in the
  # test environment the URL always points at database 1, whatever REDIS_URL
  # says. Running the specs next to a development stack then leaves the
  # development board in database 0 alone.
  def self.url
    configured = ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0")
    return configured unless Rails.env.test?

    URI.parse(configured).tap { |uri| uri.path = TEST_DATABASE }.to_s
  end

  def self.pool
    @pool ||= ConnectionPool.new(size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i + 5, timeout: 3) do
      Redis.new(url:, connect_timeout: 1, timeout: 2)
    end
  end

  def self.with(&)
    pool.with(&)
  end
end
