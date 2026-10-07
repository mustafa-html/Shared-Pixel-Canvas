# Rebuilds the board from MySQL: start from the latest snapshot (or a blank
# board) and replay every later placement in sequence order.
class BoardRebuilder
  BATCH_SIZE = 10_000

  Result = Struct.new(:bytes, :seq, :events_replayed, :snapshot_seq, keyword_init: true)

  class << self
    # Builds the board in memory without touching Redis.
    def build(upto_seq: nil, use_snapshot: true)
      snapshot = usable_snapshot(upto_seq) if use_snapshot
      bytes = snapshot ? snapshot.data.b : BoardStore.blank_bytes
      last_seq = snapshot ? snapshot.seq : 0
      replayed = 0

      each_batch(after_seq: last_seq, upto_seq:) do |rows|
        rows.each { |_seq, x, y, color| BoardBits.set(bytes, BoardConfig.index_of(x, y), color) }
        last_seq = rows.last.first
        replayed += rows.size
      end

      Result.new(bytes:, seq: last_seq, events_replayed: replayed, snapshot_seq: snapshot&.seq)
    end

    def rebuild!
      result = build
      result.seq = BoardStore.load(result.bytes, result.seq)
      result
    end

    # Rebuilds only when the board is missing. Returns :ready, :rebuilt, or
    # :locked when another process is already rebuilding.
    def ensure!
      return :ready if BoardStore.ready?

      rebuilt = false
      acquired = BoardStore.with_rebuild_lock do
        next if BoardStore.ready?

        result = rebuild!
        rebuilt = true
        Rails.logger.info(
          { event: "board.rebuilt", seq: result.seq, events_replayed: result.events_replayed,
            snapshot_seq: result.snapshot_seq }.to_json
        )
      end

      return :locked unless acquired

      rebuilt ? :rebuilt : :ready
    end

    private

    # A snapshot taken for a different board size cannot be used.
    def usable_snapshot(upto_seq)
      snapshot = BoardSnapshot.latest(upto_seq:)
      snapshot if snapshot && snapshot.data.bytesize == BoardConfig.byte_size
    end

    # Pages by sequence number, not by id: rows can be inserted out of order,
    # and replay order is what decides the final colour of a pixel.
    def each_batch(after_seq:, upto_seq:)
      loop do
        scope = PixelEvent.where("seq > ?", after_seq).order(:seq).limit(BATCH_SIZE)
        scope = scope.where(seq: ..upto_seq) if upto_seq
        rows = scope.pluck(:seq, :x, :y, :color)
        break if rows.empty?

        yield rows
        after_seq = rows.last.first
      end
    end
  end
end
