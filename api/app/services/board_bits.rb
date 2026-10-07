# Reads and writes 4-bit pixels in a byte string, using the same layout as a
# Redis bitfield: bits are counted from the most significant end, so an even
# pixel is the high half of its byte and an odd pixel is the low half.
module BoardBits
  module_function

  def get(bytes, index)
    byte = bytes.getbyte(index >> 1)
    index.even? ? byte >> 4 : byte & 0x0F
  end

  def set(bytes, index, color)
    position = index >> 1
    byte = bytes.getbyte(position)
    bytes.setbyte(position, index.even? ? (byte & 0x0F) | (color << 4) : (byte & 0xF0) | color)
  end

  # Number of pixels that differ between two boards of the same size.
  def diff_count(left, right)
    raise ArgumentError, "boards differ in size" unless left.bytesize == right.bytesize
    return 0 if left == right

    differences = 0
    left.each_byte.with_index do |byte, position|
      changed = byte ^ right.getbyte(position)
      next if changed.zero?

      differences += 1 if changed & 0xF0 != 0
      differences += 1 if changed & 0x0F != 0
    end
    differences
  end
end
