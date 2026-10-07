# Reads config/board.yml. Everything that depends on the board's shape goes
# through here.
module BoardConfig
  module_function

  def settings
    @settings ||= Rails.application.config_for(:board)
  end

  def width = settings.fetch(:width)
  def height = settings.fetch(:height)
  def palette = settings.fetch(:palette)
  def snapshot_every = settings.fetch(:snapshot_every)
  def snapshots_kept = settings.fetch(:snapshots_kept)

  def cooldown_ms
    ENV.fetch("COOLDOWN_MS") { settings.fetch(:cooldown_ms) }.to_i
  end

  def pixel_count = width * height

  # Four bits per pixel, two pixels per byte.
  def byte_size = (pixel_count + 1) / 2

  def color_count = palette.size

  def index_of(x, y) = (y * width) + x

  def valid_position?(x, y)
    x.is_a?(Integer) && y.is_a?(Integer) && x >= 0 && x < width && y >= 0 && y < height
  end

  def valid_color?(color)
    color.is_a?(Integer) && color >= 0 && color < color_count
  end
end
