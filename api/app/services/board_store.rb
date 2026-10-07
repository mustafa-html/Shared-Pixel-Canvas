require "digest/sha1"

# The live board in Redis: one bitfield, one sequence counter and a cooldown
# key per user.
class BoardStore
  BOARD_KEY = "board:v1".freeze
  SEQ_KEY = "board:seq".freeze
  REBUILD_LOCK_KEY = "board:rebuild_lock".freeze

  PLACE_SCRIPT = Rails.root.join("config/redis/place_pixel.lua").read.freeze
  PLACE_SHA = Digest::SHA1.hexdigest(PLACE_SCRIPT).freeze
  RELEASE_LOCK_SCRIPT = "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) end " \
                        "return 0".freeze

  Result = Struct.new(:status, :seq, :retry_after_ms, keyword_init: true) do
    def placed? = status == :placed
  end

  class << self
    # Returns a Result whose status is :placed, :cooldown or :not_ready.
    # Pass cooldown: false for system writes such as seeding.
    def place(user_id:, x:, y:, color:, cooldown: true)
      status, value = run_place_script(
        keys: [BOARD_KEY, SEQ_KEY, cooldown_key(user_id)],
        argv: [BoardConfig.index_of(x, y), color, cooldown ? BoardConfig.cooldown_ms : 0]
      )

      case status
      when 1 then Result.new(status: :placed, seq: value)
      when 0 then Result.new(status: :cooldown, retry_after_ms: value)
      else Result.new(status: :not_ready)
      end
    end

    # The board bytes and the sequence number they include, read together so
    # the pair is consistent. Bytes are nil when the board is missing.
    def read
      bytes, seq = AppRedis.with do |redis|
        redis.multi do |transaction|
          transaction.get(BOARD_KEY)
          transaction.get(SEQ_KEY)
        end
      end
      [bytes&.b, seq.to_i]
    end

    def ready?
      AppRedis.with { |redis| redis.exists?(BOARD_KEY) }
    end

    def seq
      AppRedis.with { |redis| redis.get(SEQ_KEY) }.to_i
    end

    # Replaces the whole board in one step. The counter never moves backwards,
    # so a sequence number is not handed out twice if only the board was lost.
    def load(bytes, seq)
      raise ArgumentError, "expected #{BoardConfig.byte_size} bytes, got #{bytes.bytesize}" \
        unless bytes.bytesize == BoardConfig.byte_size

      AppRedis.with do |redis|
        next_seq = [seq, redis.get(SEQ_KEY).to_i].max
        redis.multi do |transaction|
          transaction.set(BOARD_KEY, bytes)
          transaction.set(SEQ_KEY, next_seq)
        end
        next_seq
      end
    end

    def blank_bytes
      ("\x00".b * BoardConfig.byte_size)
    end

    def cooldown_remaining_ms(user_id)
      remaining = AppRedis.with { |redis| redis.pttl(cooldown_key(user_id)) }
      [remaining, 0].max
    end

    # Runs the block if no other process holds the lock. Returns false when
    # the lock was taken.
    def with_rebuild_lock(ttl_seconds: 120)
      token = SecureRandom.hex(8)
      acquired = AppRedis.with { |redis| redis.set(REBUILD_LOCK_KEY, token, nx: true, ex: ttl_seconds) }
      return false unless acquired

      begin
        yield
        true
      ensure
        AppRedis.with { |redis| redis.eval(RELEASE_LOCK_SCRIPT, keys: [REBUILD_LOCK_KEY], argv: [token]) }
      end
    end

    private

    def cooldown_key(user_id) = "cooldown:#{user_id}"

    # EVALSHA sends only the script's hash. After a Redis restart the script
    # cache is empty, so fall back to sending the script once.
    def run_place_script(keys:, argv:)
      AppRedis.with do |redis|
        redis.evalsha(PLACE_SHA, keys:, argv:)
      rescue Redis::CommandError => e
        raise unless e.message.start_with?("NOSCRIPT")

        redis.eval(PLACE_SCRIPT, keys:, argv:)
      end
    end
  end
end
