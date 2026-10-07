require "rails_helper"

RSpec.describe PlacePixel do
  let(:user) { create_user }

  it "stores the event with the sequence number Redis assigned" do
    result = described_class.call(user:, x: 4, y: 5, color: 6)
    event = PixelEvent.find_by!(seq: result.seq)

    expect(result).to be_placed
    expect(event).to have_attributes(user_id: user.id, x: 4, y: 5, color: 6)
    expect(pixel_at(4, 5)).to eq(6)
  end

  it "broadcasts the pixel once" do
    expect { described_class.call(user:, x: 4, y: 5, color: 6) }
      .to have_broadcasted_to(BoardChannel::STREAM)
      .exactly(:once)
      .with(hash_including(seq: 1, x: 4, y: 5, color: 6))
  end

  it "stores and broadcasts nothing while the user is on cooldown" do
    described_class.call(user:, x: 1, y: 1, color: 1)

    expect { described_class.call(user:, x: 2, y: 2, color: 2) }
      .to not_change(PixelEvent, :count)
      .and(not_change { ActionCable.server.pubsub.broadcasts(BoardChannel::STREAM).size })
  end

  it "hands the insert to a retry job when MySQL fails, and still succeeds" do
    allow(PixelEvent).to receive(:record!).and_raise(ActiveRecord::ConnectionNotEstablished)

    result = nil
    expect { result = described_class.call(user:, x: 4, y: 5, color: 6) }
      .to have_enqueued_job(PersistPixelJob).with(1, user.id, 4, 5, 6, kind_of(String))

    expect(result).to be_placed
    expect(pixel_at(4, 5)).to eq(6)
  end

  it "takes a snapshot every snapshot_every placements" do
    allow(BoardConfig).to receive(:snapshot_every).and_return(2)
    other = create_user

    expect { described_class.call(user:, x: 0, y: 0, color: 1) }.not_to have_enqueued_job(SnapshotJob)
    expect { described_class.call(user: other, x: 0, y: 0, color: 1) }.to have_enqueued_job(SnapshotJob)
  end

  it "asks for a rebuild when the board is missing" do
    AppRedis.with { |redis| redis.del(BoardStore::BOARD_KEY) }

    result = nil
    expect { result = described_class.call(user:, x: 0, y: 0, color: 1) }.to have_enqueued_job(RebuildBoardJob)
    expect(result.status).to eq(:not_ready)
  end

  it "stores exactly one event when 50 requests from one user arrive together", :threaded do
    results = Array.new(50) do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          described_class.call(user:, x: i, y: 0, color: 3)
        end
      end
    end.map(&:value)

    expect(results.count(&:placed?)).to eq(1)
    expect(PixelEvent.count).to eq(1)
    expect(PixelEvent.first.seq).to eq(BoardStore.seq)
  end
end
