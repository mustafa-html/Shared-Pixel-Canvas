module Api
  class PixelsController < ApplicationController
    before_action :require_user!, only: :create

    def create
      x = integer_param(:x)
      y = integer_param(:y)
      color = integer_param(:color)
      return render_invalid unless BoardConfig.valid_position?(x, y) && BoardConfig.valid_color?(color)

      result = PlacePixel.call(user: current_user, x:, y:, color:)

      case result.status
      when :placed
        render json: { seq: result.seq, x:, y:, color:, cooldown_ms: BoardConfig.cooldown_ms },
               status: :created
      when :cooldown
        render json: { error: "cooldown", retry_after_ms: result.retry_after_ms }, status: :too_many_requests
      else
        render_board_rebuilding
      end
    end

    # Who placed the pixel that is currently showing at this position.
    def show
      x = integer_param(:x)
      y = integer_param(:y)
      return render_invalid unless BoardConfig.valid_position?(x, y)

      event = PixelEvent.includes(:user).latest_at(x, y)
      return render json: { error: "never_placed" }, status: :not_found if event.nil?

      render json: {
        x: event.x, y: event.y, color: event.color, seq: event.seq,
        placed_by: event.user.display_name, placed_at: event.created_at.iso8601(3)
      }
    end

    private

    def render_invalid
      render json: {
        error: "invalid_pixel",
        message: "x must be 0 to #{BoardConfig.width - 1}, y 0 to #{BoardConfig.height - 1} " \
                 "and color 0 to #{BoardConfig.color_count - 1}, all whole numbers."
      }, status: 422
    end
  end
end
