require "rails_helper"

RSpec.describe ConsistencyChecker do
  let(:users) { Array.new(40) { create_user } }

  it "finds no differences after 10,000 placements by many users on overlapping pixels" do
    random = Random.new(2026)
    10_000.times { place!(users.sample(random:), random.rand(24), random.rand(24), random.rand(16)) }

    report = described_class.run

    expect(report).to have_attributes(differences: 0, live_seq: 10_000, events_replayed: 10_000, unrecorded: 0)
    expect(report).to be_consistent
  end

  it "reports a pixel that Redis has and MySQL does not" do
    user = users.first
    place!(user, 1, 1, 5)
    BoardStore.place(user_id: user.id, x: 2, y: 2, color: 7, cooldown: false)

    expect(described_class.run).to have_attributes(differences: 1, unrecorded: 1)
  end

  it "raises when the board is missing" do
    AppRedis.with(&:flushdb)

    expect { described_class.run }.to raise_error(described_class::BoardMissing)
  end
end
