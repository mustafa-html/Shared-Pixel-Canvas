# Saves the current board and its sequence number to MySQL so a rebuild only
# has to replay the placements made since.
class SnapshotJob < ApplicationJob
  queue_as :default

  def perform
    bytes, seq = BoardStore.read
    return if bytes.nil?
    return if BoardSnapshot.exists?(seq: seq..)

    BoardSnapshot.create!(seq:, data: bytes)
    BoardSnapshot.prune!(keep: BoardConfig.snapshots_kept)
  end
end
