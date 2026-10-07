# One accepted placement. Rows are written once and never changed.
class PixelEvent < ApplicationRecord
  belongs_to :user

  # A single INSERT with no extra queries. The controller has already validated
  # the values, and the table's constraints guard the rest. Raises
  # ActiveRecord::RecordNotUnique if this sequence number is already stored.
  def self.record!(seq:, user_id:, x:, y:, color:, placed_at: Time.current)
    insert!({ seq:, user_id:, x:, y:, color:, created_at: placed_at })
  end

  def self.latest_at(x, y)
    where(x:, y:).order(seq: :desc).first
  end

  def readonly?
    persisted?
  end
end
