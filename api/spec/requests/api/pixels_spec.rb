require "rails_helper"

RSpec.describe "Pixels API" do
  describe "POST /api/pixels" do
    it "requires a session" do
      post_pixel(1, 1, 1)

      expect(response).to have_http_status(:unauthorized)
      expect(json["error"]).to eq("no_session")
    end

    it "places a pixel and returns its sequence number" do
      user = start_session

      expect { post_pixel(10, 20, 5) }.to change(PixelEvent, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to eq("seq" => 1, "x" => 10, "y" => 20, "color" => 5, "cooldown_ms" => BoardConfig.cooldown_ms)
      expect(PixelEvent.last).to have_attributes(seq: 1, user_id: user.id, x: 10, y: 20, color: 5)
      expect(pixel_at(10, 20)).to eq(5)
    end

    it "refuses a second placement inside the cooldown with the time left" do
      start_session
      post_pixel(1, 1, 1)

      expect { post_pixel(2, 2, 2) }.not_to change(PixelEvent, :count)
      expect(response).to have_http_status(:too_many_requests)
      expect(json["error"]).to eq("cooldown")
      expect(json["retry_after_ms"]).to be_between(1, BoardConfig.cooldown_ms)
      expect(pixel_at(2, 2)).to eq(0)
    end

    [
      ["x below the board", { x: -1, y: 0, color: 1 }],
      ["x past the board", { x: 512, y: 0, color: 1 }],
      ["y past the board", { x: 0, y: 512, color: 1 }],
      ["a colour outside the palette", { x: 0, y: 0, color: 16 }],
      ["a fractional coordinate", { x: 1.5, y: 0, color: 1 }],
      ["a non-numeric coordinate", { x: "abc", y: 0, color: 1 }],
      ["a missing colour", { x: 0, y: 0 }]
    ].each do |description, body|
      it "rejects #{description} and changes nothing" do
        start_session

        expect { post "/api/pixels", params: body, as: :json }.not_to change(PixelEvent, :count)
        expect(response).to have_http_status(422)
        expect(json["error"]).to eq("invalid_pixel")
        expect(BoardStore.read).to eq([BoardStore.blank_bytes, 0])
      end
    end

    it "does not start the cooldown for a rejected placement" do
      start_session
      post_pixel(999, 0, 1)
      post_pixel(0, 0, 1)

      expect(response).to have_http_status(:created)
    end

    it "answers 503 while the board is missing" do
      start_session
      AppRedis.with { |redis| redis.del(BoardStore::BOARD_KEY) }

      post_pixel(0, 0, 1)

      expect(response).to have_http_status(:service_unavailable)
      expect(json["error"]).to eq("board_rebuilding")
    end
  end

  describe "GET /api/pixels/:x/:y" do
    it "returns the latest placement at that position" do
      first = create_user
      second = create_user
      place!(first, 7, 8, 2)
      place!(second, 7, 8, 9)

      get "/api/pixels/7/8"

      expect(response).to have_http_status(:ok)
      expect(json).to include("x" => 7, "y" => 8, "color" => 9, "seq" => 2, "placed_by" => second.display_name)
      expect(Time.iso8601(json["placed_at"])).to be_within(5.seconds).of(Time.current)
    end

    it "returns 404 for a pixel nobody has placed" do
      get "/api/pixels/7/8"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("never_placed")
    end

    it "returns 422 outside the board" do
      get "/api/pixels/512/0"

      expect(response).to have_http_status(422)
    end
  end
end
