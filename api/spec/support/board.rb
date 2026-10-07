# Every example starts with an empty Redis database and a blank board.
RSpec.configure do |config|
  config.before do
    AppRedis.with(&:flushdb)
    BoardStore.load(BoardStore.blank_bytes, 0)
  end

  # Examples that use threads cannot share the test transaction, so they
  # commit for real and clean up afterwards.
  config.around(:each, :threaded) do |example|
    self.use_transactional_tests = false
    example.run
  ensure
    PixelEvent.delete_all
    BoardSnapshot.delete_all
    User.delete_all
  end
end

module BoardHelpers
  def create_user
    User.create_guest!
  end

  def pixel_at(x, y)
    bytes, = BoardStore.read
    BoardBits.get(bytes, BoardConfig.index_of(x, y))
  end

  # Places a pixel the way the application does, without the cooldown.
  def place!(user, x, y, color)
    result = BoardStore.place(user_id: user.id, x:, y:, color:, cooldown: false)
    PixelEvent.record!(seq: result.seq, user_id: user.id, x:, y:, color:)
    result.seq
  end
end

RSpec.configure { |config| config.include BoardHelpers }
