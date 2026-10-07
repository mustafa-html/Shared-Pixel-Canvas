require "rails_helper"

RSpec.describe BoardChannel, type: :channel do
  it "streams the shared board to every subscriber" do
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("board")
  end

  it "exposes no actions a client could call" do
    expect(described_class.action_methods).to be_empty
  end

  it "broadcasts a pixel with its sequence number and time" do
    placed_at = Time.utc(2026, 10, 8, 12, 0, 0)

    expect { described_class.broadcast_pixel(seq: 9, x: 1, y: 2, color: 3, placed_at:) }
      .to have_broadcasted_to("board").with(seq: 9, x: 1, y: 2, color: 3, t: 1_791_460_800_000)
  end

  it "does not raise when the broadcast fails" do
    allow(ActionCable.server).to receive(:broadcast).and_raise(Redis::CannotConnectError)

    expect { described_class.broadcast_pixel(seq: 1, x: 0, y: 0, color: 0) }.not_to raise_error
  end
end
