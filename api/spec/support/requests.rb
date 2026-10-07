module RequestHelpers
  def json
    JSON.parse(response.body)
  end

  # Starts a guest session; the cookie stays in the test session's jar.
  def start_session
    get "/api/session"
    User.find(json.dig("user", "id"))
  end

  def post_pixel(x, y, color)
    post "/api/pixels", params: { x:, y:, color: }, as: :json
  end
end

RSpec.configure { |config| config.include RequestHelpers, type: :request }
