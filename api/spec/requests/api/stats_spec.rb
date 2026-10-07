require "rails_helper"

RSpec.describe "GET /api/stats" do
  it "counts placements and users" do
    user = create_user
    create_user
    place!(user, 0, 0, 1)
    place!(user, 1, 0, 1)
    place!(user, 2, 0, 1)

    get "/api/stats"

    expect(json).to eq("total_placements" => 3, "total_users" => 2)
  end
end
