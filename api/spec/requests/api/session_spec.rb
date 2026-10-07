require "rails_helper"

RSpec.describe "GET /api/session" do
  it "creates a guest on the first call and returns the board configuration" do
    expect { get "/api/session" }.to change(User, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(json["user"]["display_name"]).to match(/\AGuest \d{4}\z/)
    expect(json["cooldown_remaining_ms"]).to eq(0)
    expect(json["board"]).to include(
      "width" => BoardConfig.width, "height" => BoardConfig.height,
      "cooldown_ms" => BoardConfig.cooldown_ms, "palette" => BoardConfig.palette
    )
    expect(json["board"]["palette"].size).to eq(16)
  end

  it "returns the same guest on later calls" do
    first = start_session

    expect { get "/api/session" }.not_to change(User, :count)
    expect(json["user"]["id"]).to eq(first.id)
  end

  it "does not expose the guest token to scripts" do
    get "/api/session"

    expect(response.headers["Set-Cookie"].to_s).to match(/guest_token=.*httponly/i)
    expect(response.body).not_to include(User.last.guest_token)
  end

  it "reports the cooldown left after a placement" do
    start_session
    post_pixel(1, 1, 1)
    get "/api/session"

    expect(json["cooldown_remaining_ms"]).to be_between(1, BoardConfig.cooldown_ms)
  end

  it "ignores a forged cookie" do
    victim = create_user
    cookies[:guest_token] = victim.guest_token

    expect { get "/api/session" }.to change(User, :count).by(1)
    expect(json["user"]["id"]).not_to eq(victim.id)
  end
end
