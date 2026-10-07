# Stores a placement whose first insert failed. Safe to run any number of
# times: the unique index on seq turns a repeat into a no-op.
class PersistPixelJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::ActiveRecordError, attempts: 10, wait: ->(executions) { (executions**2) + 2 }
  discard_on ActiveRecord::RecordNotUnique

  def perform(seq, user_id, x, y, color, placed_at)
    PixelEvent.record!(
      seq:, user_id:, x:, y:, color:, placed_at: Time.iso8601(placed_at)
    )
  end
end
