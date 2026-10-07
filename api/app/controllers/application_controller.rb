class ApplicationController < ActionController::API
  include ActionController::Cookies

  GUEST_COOKIE = :guest_token

  private

  def current_user
    return @current_user if defined?(@current_user)

    token = cookies.signed[GUEST_COOKIE]
    @current_user = token.present? ? User.find_by(guest_token: token) : nil
  end

  def require_user!
    return if current_user

    render json: { error: "no_session", message: "Call GET /api/session first." }, status: :unauthorized
  end

  def render_board_rebuilding
    response.set_header("Retry-After", "2")
    render json: { error: "board_rebuilding", retry_after_ms: 2000 }, status: :service_unavailable
  end

  # Accepts a JSON integer or a string of digits. Anything else, including
  # 1.5 and "1e3", is nil.
  def integer_param(key)
    value = params[key]
    case value
    when Integer then value
    when String then value.to_i if value.match?(/\A\d{1,5}\z/)
    end
  end
end
