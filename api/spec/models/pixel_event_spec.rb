require "rails_helper"

RSpec.describe PixelEvent do
  let(:user) { create_user }

  it "refuses a second row with the same sequence number" do
    described_class.record!(seq: 1, user_id: user.id, x: 0, y: 0, color: 1)

    expect { described_class.record!(seq: 1, user_id: user.id, x: 5, y: 5, color: 2) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "is append-only" do
    described_class.record!(seq: 1, user_id: user.id, x: 0, y: 0, color: 1)
    event = described_class.find_by!(seq: 1)

    expect { event.update!(color: 2) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "finds the latest placement at a position by sequence number, not insert order" do
    described_class.record!(seq: 8, user_id: user.id, x: 2, y: 2, color: 7)
    described_class.record!(seq: 3, user_id: user.id, x: 2, y: 2, color: 4)

    expect(described_class.latest_at(2, 2).color).to eq(7)
  end

  it "refuses an event for a user that does not exist" do
    expect { described_class.record!(seq: 1, user_id: 0, x: 0, y: 0, color: 1) }
      .to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
