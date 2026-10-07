require "rails_helper"

RSpec.describe PersistPixelJob do
  let(:user) { create_user }
  let(:placed_at) { "2026-10-08T12:00:00.123456Z" }

  it "stores the event with its original time" do
    described_class.perform_now(5, user.id, 1, 2, 3, placed_at)

    expect(PixelEvent.find_by!(seq: 5)).to have_attributes(
      user_id: user.id, x: 1, y: 2, color: 3, created_at: Time.iso8601(placed_at)
    )
  end

  it "leaves one row when it runs twice for the same event" do
    2.times { described_class.perform_now(5, user.id, 1, 2, 3, placed_at) }

    expect(PixelEvent.where(seq: 5).count).to eq(1)
  end

  it "retries when the database is unavailable" do
    allow(PixelEvent).to receive(:record!).and_raise(ActiveRecord::ConnectionNotEstablished)

    expect { described_class.perform_now(5, user.id, 1, 2, 3, placed_at) }
      .to have_enqueued_job(described_class).with(5, user.id, 1, 2, 3, placed_at)
  end
end
