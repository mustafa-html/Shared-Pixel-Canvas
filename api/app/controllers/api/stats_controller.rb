module Api
  class StatsController < ApplicationController
    def show
      render json: { total_placements: PixelEvent.count, total_users: User.count }
    end
  end
end
