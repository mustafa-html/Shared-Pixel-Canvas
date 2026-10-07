import { describe, expect, it } from "vitest";
import { unpackBoard } from "./bits";

describe("unpackBoard", () => {
  it("reads an even pixel from the high half of its byte and an odd pixel from the low half", () => {
    const colors = unpackBoard(new Uint8Array([0xab, 0x3c]), 4);

    expect([...colors]).toEqual([0xa, 0xb, 0x3, 0xc]);
  });

  it("matches the bytes Redis produces for BITFIELD SET u4", () => {
    // BITFIELD board SET u4 #0 9  -> first byte 0x90
    // BITFIELD board SET u4 #1 6  -> first byte 0x96
    // BITFIELD board SET u4 #5 15 -> third byte 0x0f
    const colors = unpackBoard(new Uint8Array([0x96, 0x00, 0x0f]), 6);

    expect([...colors]).toEqual([9, 6, 0, 0, 0, 15]);
  });

  it("reads the last pixel of a full-size board", () => {
    const bytes = new Uint8Array((512 * 512) / 2);
    bytes[bytes.length - 1] = 0x0e;

    const colors = unpackBoard(bytes, 512 * 512);

    expect(colors[512 * 512 - 1]).toBe(0xe);
    expect(colors[512 * 512 - 2]).toBe(0);
  });

  it("rejects a board of the wrong size", () => {
    expect(() => unpackBoard(new Uint8Array(3), 4)).toThrow(/expected 2 board bytes/);
  });
});
