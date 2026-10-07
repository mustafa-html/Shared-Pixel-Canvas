require "rails_helper"

RSpec.describe BoardStore do
  let(:last_x) { BoardConfig.width - 1 }
  let(:last_y) { BoardConfig.height - 1 }

  describe ".place" do
    it "writes the first pixel into the high half of the first byte" do
      described_class.place(user_id: 1, x: 0, y: 0, color: 9)
      bytes, = described_class.read

      expect(bytes.getbyte(0)).to eq(0x90)
      expect(bytes.bytesize).to eq(BoardConfig.byte_size)
    end

    it "writes the last pixel into the low half of the last byte" do
      described_class.place(user_id: 1, x: last_x, y: last_y, color: 0xF)
      bytes, = described_class.read

      expect(bytes.getbyte(BoardConfig.byte_size - 1)).to eq(0x0F)
    end

    it "changes exactly one pixel" do
      described_class.place(user_id: 1, x: 10, y: 20, color: 6)
      bytes, = described_class.read

      expect(BoardBits.diff_count(bytes, described_class.blank_bytes)).to eq(1)
      expect(pixel_at(10, 20)).to eq(6)
    end

    it "agrees with the Ruby bit layout used by the rebuilder" do
      expected = described_class.blank_bytes
      [[0, 0, 1], [1, 0, 2], [last_x, 0, 3], [0, 1, 4], [last_x, last_y, 5]].each_with_index do |(x, y, color), user|
        described_class.place(user_id: user, x:, y:, color:)
        BoardBits.set(expected, BoardConfig.index_of(x, y), color)
      end

      expect(described_class.read.first).to eq(expected)
    end

    it "hands out increasing sequence numbers" do
      seqs = Array.new(3) { |user| described_class.place(user_id: user, x: 0, y: 0, color: 1).seq }

      expect(seqs).to eq([1, 2, 3])
      expect(described_class.seq).to eq(3)
    end

    it "refuses a second placement inside the cooldown and reports the time left" do
      described_class.place(user_id: 7, x: 1, y: 1, color: 2)
      second = described_class.place(user_id: 7, x: 2, y: 2, color: 3)

      expect(second.status).to eq(:cooldown)
      expect(second.retry_after_ms).to be_between(1, BoardConfig.cooldown_ms)
      expect(pixel_at(2, 2)).to eq(0)
      expect(described_class.seq).to eq(1)
    end

    it "accepts another placement once the cooldown has passed" do
      allow(BoardConfig).to receive(:cooldown_ms).and_return(60)
      described_class.place(user_id: 7, x: 1, y: 1, color: 2)
      sleep 0.1

      expect(described_class.place(user_id: 7, x: 2, y: 2, color: 3)).to be_placed
    end

    it "keeps one user's cooldown from affecting another user" do
      described_class.place(user_id: 1, x: 1, y: 1, color: 2)

      expect(described_class.place(user_id: 2, x: 1, y: 1, color: 3)).to be_placed
    end

    it "reports not_ready when the board is missing, and does not create a short board" do
      AppRedis.with { |redis| redis.del(described_class::BOARD_KEY) }

      expect(described_class.place(user_id: 1, x: 5, y: 5, color: 1).status).to eq(:not_ready)
      expect(described_class).not_to be_ready
    end

    it "still works after Redis forgets its cached scripts" do
      described_class.place(user_id: 1, x: 0, y: 0, color: 1)
      AppRedis.with { |redis| redis.script(:flush) }

      expect(described_class.place(user_id: 2, x: 0, y: 0, color: 2)).to be_placed
    end
  end

  describe "concurrency" do
    it "lets one user through exactly once when 50 requests arrive together" do
      results = Array.new(50) do |i|
        Thread.new { described_class.place(user_id: 42, x: i, y: 0, color: 1) }
      end.map(&:value)

      expect(results.count(&:placed?)).to eq(1)
      expect(results.count { |result| result.status == :cooldown }).to eq(49)
      expect(described_class.seq).to eq(1)
    end

    it "gives two users on the same pixel a definite winner: the higher sequence number" do
      results = Array.new(40) do |user|
        Thread.new { [user % 16, described_class.place(user_id: user, x: 3, y: 3, color: user % 16)] }
      end.map(&:value)

      winning_color, = results.max_by { |_color, result| result.seq }
      expect(results.map { |_color, result| result.seq }.sort).to eq((1..40).to_a)
      expect(pixel_at(3, 3)).to eq(winning_color)
    end
  end

  describe ".load" do
    it "rejects bytes of the wrong size" do
      expect { described_class.load("\x00".b, 0) }.to raise_error(ArgumentError)
    end

    it "never moves the sequence counter backwards" do
      described_class.load(described_class.blank_bytes, 50)

      expect(described_class.load(described_class.blank_bytes, 10)).to eq(50)
      expect(described_class.seq).to eq(50)
    end
  end

  describe ".with_rebuild_lock" do
    it "runs one block at a time and releases the lock afterwards" do
      inner = nil
      outer = described_class.with_rebuild_lock { inner = described_class.with_rebuild_lock { nil } }

      expect(outer).to be(true)
      expect(inner).to be(false)
      expect(described_class.with_rebuild_lock { nil }).to be(true)
    end
  end
end

RSpec.describe AppRedis do
  it "always uses database 1 in the test environment, whatever REDIS_URL says" do
    stub_const("ENV", ENV.to_h.merge("REDIS_URL" => "redis://redis:6379/0"))

    expect(described_class.url).to eq("redis://redis:6379/1")
  end
end
