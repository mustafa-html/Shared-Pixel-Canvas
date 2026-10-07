require "rails_helper"

RSpec.describe BoardSeeder do
  it "draws through the normal path, so the drawing survives a rebuild" do
    count = described_class.run

    expect(count).to eq(described_class.cells.size)
    expect(PixelEvent.count).to eq(count)
    expect(ConsistencyChecker.run).to be_consistent
  end

  it "leaves a board that already has history alone" do
    place!(create_user, 0, 0, 1)

    expect(described_class.run).to eq(0)
  end
end
