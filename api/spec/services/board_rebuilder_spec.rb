require "rails_helper"

RSpec.describe BoardRebuilder do
  let(:users) { Array.new(5) { create_user } }

  def scribble(count, random: Random.new(1))
    count.times do
      place!(users.sample(random:), random.rand(8), random.rand(8), random.rand(16))
    end
  end

  def wipe_redis
    AppRedis.with(&:flushdb)
  end

  describe ".build" do
    it "replays the history into the same bytes as the live board" do
      scribble(300)

      expect(described_class.build.bytes).to eq(BoardStore.read.first)
    end

    it "replays in sequence order even when rows were inserted out of order" do
      user = users.first
      PixelEvent.record!(seq: 2, user_id: user.id, x: 0, y: 0, color: 9)
      PixelEvent.record!(seq: 1, user_id: user.id, x: 0, y: 0, color: 4)

      expect(BoardBits.get(described_class.build.bytes, 0)).to eq(9)
    end

    it "gives the same bytes from a snapshot as from a full replay" do
      scribble(150)
      SnapshotJob.perform_now
      scribble(150, random: Random.new(2))

      from_snapshot = described_class.build
      full_replay = described_class.build(use_snapshot: false)

      expect(from_snapshot.snapshot_seq).to eq(150)
      expect(from_snapshot.events_replayed).to eq(150)
      expect(full_replay.events_replayed).to eq(300)
      expect(from_snapshot.bytes).to eq(full_replay.bytes)
    end

    it "pages through more events than one batch holds" do
      stub_const("BoardRebuilder::BATCH_SIZE", 7)
      scribble(40)

      result = described_class.build
      expect(result.events_replayed).to eq(40)
      expect(result.bytes).to eq(BoardStore.read.first)
    end

    it "ignores a snapshot taken for a different board size" do
      BoardSnapshot.create!(seq: 99, data: "\x11".b)
      scribble(10)

      expect(described_class.build.snapshot_seq).to be_nil
    end

    it "stops at upto_seq" do
      scribble(20)

      expect(described_class.build(upto_seq: 5).seq).to eq(5)
    end
  end

  describe ".ensure!" do
    it "leaves an existing board alone" do
      expect(described_class.ensure!).to eq(:ready)
    end

    it "brings back an identical board and sequence number after Redis is wiped" do
      scribble(200)
      before, seq_before = BoardStore.read
      wipe_redis

      expect(described_class.ensure!).to eq(:rebuilt)
      expect(BoardStore.read).to eq([before, seq_before])
    end

    it "builds a blank board when there is no history" do
      wipe_redis

      expect(described_class.ensure!).to eq(:rebuilt)
      expect(BoardStore.read).to eq([BoardStore.blank_bytes, 0])
    end

    it "continues numbering after the last stored event" do
      scribble(12)
      wipe_redis
      described_class.ensure!

      expect(place!(users.first, 0, 0, 1)).to eq(13)
    end

    it "does nothing while another process is rebuilding" do
      wipe_redis
      AppRedis.with { |redis| redis.set(BoardStore::REBUILD_LOCK_KEY, "someone-else", ex: 30) }

      expect(described_class.ensure!).to eq(:locked)
      expect(BoardStore).not_to be_ready
    end
  end
end
