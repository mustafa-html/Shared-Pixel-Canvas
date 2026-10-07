// The board travels as raw bytes with four bits per pixel. Redis bitfields
// count bits from the most significant end, so an even pixel is the high half
// of its byte and an odd pixel is the low half. The server's BoardBits module
// uses the same layout.

export function unpackBoard(bytes: Uint8Array, pixelCount: number): Uint8Array {
  const expected = Math.ceil(pixelCount / 2);
  if (bytes.length !== expected) {
    throw new Error(`expected ${expected} board bytes, got ${bytes.length}`);
  }

  const colors = new Uint8Array(pixelCount);
  for (let index = 0; index < pixelCount; index++) {
    const byte = bytes[index >> 1];
    colors[index] = (index & 1) === 0 ? byte >> 4 : byte & 0x0f;
  }
  return colors;
}
