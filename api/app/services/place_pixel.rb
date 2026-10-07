# The placement path: Redis decides, MySQL records, Action Cable announces.
class PlacePixel
  def self.call(user:, x:, y:, color:)
    new(user:, x:, y:, color:).call
  end

  def initialize(user:, x:, y:, color:)
    @user = user
    @x = x
    @y = y
    @color = color
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = BoardStore.place(user_id: @user.id, x: @x, y: @y, color: @color)

    case result.status
    when :placed then after_placement(result.seq)
    when :not_ready then RebuildBoardJob.perform_later
    end

    log(result, started)
    result
  end

  private

  def after_placement(seq)
    placed_at = Time.current
    record(seq, placed_at)
    BoardChannel.broadcast_pixel(seq:, x: @x, y: @y, color: @color, placed_at:)
    SnapshotJob.perform_later if (seq % BoardConfig.snapshot_every).zero?
  end

  # Redis has already accepted the pixel, so a database failure must not fail
  # the request. The job retries until the row is stored.
  def record(seq, placed_at)
    PixelEvent.record!(seq:, user_id: @user.id, x: @x, y: @y, color: @color, placed_at:)
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.warn({ event: "pixel.duplicate_seq", seq: }.to_json)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error({ event: "pixel.insert_failed", seq:, error: e.class.name }.to_json)
    PersistPixelJob.perform_later(seq, @user.id, @x, @y, @color, placed_at.iso8601(6))
  end

  def log(result, started)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
    Rails.logger.info(
      { event: "pixel.place", result: result.status, seq: result.seq, user_id: @user.id,
        x: @x, y: @y, color: @color, duration_ms: }.to_json
    )
  end
end
