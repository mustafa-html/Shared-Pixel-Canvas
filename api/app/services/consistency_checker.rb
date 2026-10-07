# Replays the full history from MySQL and compares it with the live board.
class ConsistencyChecker
  class BoardMissing < StandardError; end

  Report = Struct.new(:differences, :live_seq, :events_replayed, :unrecorded, keyword_init: true) do
    def consistent? = differences.zero?
  end

  # differences: pixels whose colour differs between Redis and the replay.
  # unrecorded:  sequence numbers up to live_seq with no row in MySQL, that is
  #              placements Redis accepted that were never stored.
  def self.run
    live_bytes, live_seq = BoardStore.read
    raise BoardMissing, "the board is not in Redis; run board:ensure first" if live_bytes.nil?

    replay = BoardRebuilder.build(upto_seq: live_seq, use_snapshot: false)

    Report.new(
      differences: BoardBits.diff_count(live_bytes, replay.bytes),
      live_seq:,
      events_replayed: replay.events_replayed,
      unrecorded: live_seq - replay.events_replayed
    )
  end
end
