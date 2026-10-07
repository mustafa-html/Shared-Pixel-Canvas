# Draws a small heart in the middle of an empty board so the first visitor
# does not see a blank page. Seeded pixels go through the same path as real
# ones, so they are part of the history and survive a rebuild.
class BoardSeeder
  SCALE = 4
  RED = 5
  ART = [
    "..XXX...XXX..",
    ".XXXXX.XXXXX.",
    "XXXXXXXXXXXXX",
    "XXXXXXXXXXXXX",
    "XXXXXXXXXXXXX",
    ".XXXXXXXXXXX.",
    "..XXXXXXXXX..",
    "...XXXXXXX...",
    "....XXXXX....",
    ".....XXX.....",
    "......X......"
  ].freeze

  def self.run(force: false)
    return 0 if PixelEvent.exists? && !force
    raise "the board is not ready; run board:ensure first" unless BoardStore.ready?

    user = User.find_or_create_by!(display_name: "Canvas") do |seed_user|
      seed_user.guest_token = SecureRandom.hex(32)
      seed_user.last_seen_at = Time.current
    end

    cells.count do |x, y|
      result = BoardStore.place(user_id: user.id, x:, y:, color: RED, cooldown: false)
      PixelEvent.record!(seq: result.seq, user_id: user.id, x:, y:, color: RED)
    end
  end

  def self.cells
    left = (BoardConfig.width - (ART.first.size * SCALE)) / 2
    upper = (BoardConfig.height - (ART.size * SCALE)) / 2

    ART.each_with_index.flat_map do |row, row_index|
      row.each_char.with_index.flat_map do |cell, column_index|
        next [] unless cell == "X"

        Array.new(SCALE * SCALE) do |i|
          [left + (column_index * SCALE) + (i % SCALE), upper + (row_index * SCALE) + (i / SCALE)]
        end
      end
    end
  end
end
