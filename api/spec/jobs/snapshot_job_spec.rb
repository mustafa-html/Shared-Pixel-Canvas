require "rails_helper"

RSpec.describe SnapshotJob do
  let(:user) { create_user }

  it "saves the board bytes with the sequence number they include" do
    place!(user, 0, 0, 0xA)
    place!(user, 1, 0, 0xB)

    described_class.perform_now

    snapshot = BoardSnapshot.last
    expect(snapshot.seq).to eq(2)
    expect(snapshot.data.bytesize).to eq(BoardConfig.byte_size)
    expect(snapshot.data.getbyte(0)).to eq(0xAB)
  end

  it "does not save the same state twice" do
    place!(user, 0, 0, 1)

    expect { 2.times { described_class.perform_now } }.to change(BoardSnapshot, :count).by(1)
  end

  it "keeps only the most recent snapshots" do
    allow(BoardConfig).to receive(:snapshots_kept).and_return(2)

    4.times do |i|
      place!(user, i, 0, 1)
      described_class.perform_now
    end

    expect(BoardSnapshot.order(:seq).pluck(:seq)).to eq([3, 4])
  end

  it "does nothing when the board is missing" do
    AppRedis.with(&:flushdb)

    expect { described_class.perform_now }.not_to change(BoardSnapshot, :count)
  end
end
