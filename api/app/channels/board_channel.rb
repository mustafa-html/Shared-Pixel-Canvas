# One public stream that every open browser listens to. Messages only travel
# from server to client; placements go through POST /api/pixels so that
# validation lives in one place.
class BoardChannel < ApplicationCable::Channel
  STREAM = "board".freeze

  # placed_at is sent as epoch milliseconds so a client, or the load test, can
  # measure how long delivery took.
  def self.broadcast_pixel(seq:, x:, y:, color:, placed_at: Time.current)
    ActionCable.server.broadcast(
      STREAM, { seq:, x:, y:, color:, t: (placed_at.to_f * 1000).round }
    )
  rescue StandardError => e
    # The pixel is already stored. Clients that miss the message catch up on
    # their next board fetch.
    Rails.logger.error({ event: "pixel.broadcast_failed", seq:, error: e.class.name }.to_json)
  end

  private

  # Private so that it is a lifecycle callback only. A public method on a
  # channel is an action any client can call.
  def subscribed
    stream_from STREAM
  end
end
