module Api
  class SessionsController < ApplicationController
    # Returns the visitor's guest identity, creating it on the first call, and
    # the board configuration the client needs to draw anything.
    def show
      user = current_user || create_guest
      user.seen!

      render json: {
        user: { id: user.id, display_name: user.display_name },
        cooldown_remaining_ms: BoardStore.cooldown_remaining_ms(user.id),
        board: {
          width: BoardConfig.width,
          height: BoardConfig.height,
          palette: BoardConfig.palette,
          cooldown_ms: BoardConfig.cooldown_ms
        }
      }
    end

    private

    def create_guest
      user = User.create_guest!
      cookies.permanent.signed[GUEST_COOKIE] = { value: user.guest_token, httponly: true, same_site: :lax }
      user
    end
  end
end
