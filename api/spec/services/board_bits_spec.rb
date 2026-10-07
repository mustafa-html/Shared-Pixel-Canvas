require "rails_helper"

RSpec.describe BoardBits do
  let(:bytes) { "\x00\x00".b }

  it "stores an even pixel in the high half of its byte" do
    described_class.set(bytes, 0, 0xA)

    expect(bytes.bytes).to eq([0xA0, 0x00])
  end

  it "stores an odd pixel in the low half of its byte" do
    described_class.set(bytes, 1, 0xB)

    expect(bytes.bytes).to eq([0x0B, 0x00])
  end

  it "leaves the neighbouring pixel untouched" do
    described_class.set(bytes, 2, 0xF)
    described_class.set(bytes, 3, 0x1)
    described_class.set(bytes, 2, 0x7)

    expect(described_class.get(bytes, 2)).to eq(0x7)
    expect(described_class.get(bytes, 3)).to eq(0x1)
  end

  it "counts differing pixels, not differing bytes" do
    left = "\x12\x34".b
    right = "\x1F\x00".b

    expect(described_class.diff_count(left, right)).to eq(3)
    expect(described_class.diff_count(left, left.dup)).to eq(0)
  end

  it "refuses to compare boards of different sizes" do
    expect { described_class.diff_count("\x00".b, "\x00\x00".b) }.to raise_error(ArgumentError)
  end
end
