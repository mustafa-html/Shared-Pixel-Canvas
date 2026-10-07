# Enqueued when a request finds the board missing from Redis.
class RebuildBoardJob < ApplicationJob
  queue_as :default

  def perform
    BoardRebuilder.ensure!
  end
end
