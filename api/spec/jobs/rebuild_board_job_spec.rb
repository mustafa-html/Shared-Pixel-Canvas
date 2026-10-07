require "rails_helper"

RSpec.describe RebuildBoardJob do
  it "restores a missing board from the history" do
    place!(create_user, 3, 3, 8)
    AppRedis.with(&:flushdb)

    described_class.perform_now

    expect(pixel_at(3, 3)).to eq(8)
    expect(BoardStore.seq).to eq(1)
  end
end
