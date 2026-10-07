require "rails_helper"

RSpec.describe "GET /api/board" do
  it "returns the raw board bytes and the sequence number they include" do
    user = create_user
    place!(user, 0, 0, 0xC)
    place!(user, 1, 0, 0x3)

    get "/api/board"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/octet-stream")
    expect(response.headers["X-Board-Seq"]).to eq("2")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body.bytesize).to eq(BoardConfig.byte_size)
    expect(response.body.getbyte(0)).to eq(0xC3)
  end

  it "answers 503 and asks for a rebuild while the board is missing" do
    AppRedis.with(&:flushdb)

    expect { get "/api/board" }.to have_enqueued_job(RebuildBoardJob)
    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers["Retry-After"]).to eq("2")
    expect(json["error"]).to eq("board_rebuilding")
  end
end
