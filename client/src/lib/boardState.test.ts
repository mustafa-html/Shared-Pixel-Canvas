import { describe, expect, it } from "vitest";
import { BoardState } from "./boardState";

// A 4 by 2 board is four bytes.
function blank(): Uint8Array {
  return new Uint8Array(4);
}

function loaded(seq = 0): BoardState {
  const state = new BoardState(4, 2);
  state.beginSync();
  state.loadSnapshot(blank(), seq);
  return state;
}

describe("BoardState", () => {
  it("applies a live message to a loaded board", () => {
    const state = loaded();

    expect(state.receive({ seq: 1, x: 2, y: 1, color: 7 })).toBe(true);
    expect(state.colorAt(2, 1)).toBe(7);
  });

  it("keeps the newer colour when broadcasts arrive out of order", () => {
    const state = loaded();

    state.receive({ seq: 9, x: 0, y: 0, color: 3 });
    const changed = state.receive({ seq: 8, x: 0, y: 0, color: 5 });

    expect(changed).toBe(false);
    expect(state.colorAt(0, 0)).toBe(3);
  });

  it("tracks sequence numbers per pixel, so an old update to another pixel still applies", () => {
    const state = loaded(10);

    state.receive({ seq: 15, x: 0, y: 0, color: 3 });

    expect(state.receive({ seq: 12, x: 1, y: 0, color: 4 })).toBe(true);
    expect(state.colorAt(1, 0)).toBe(4);
  });

  it("holds messages that arrive before the board and applies them after it loads", () => {
    const state = new BoardState(4, 2);
    state.beginSync();

    expect(state.receive({ seq: 6, x: 3, y: 1, color: 9 })).toBe(false);
    const changed = state.loadSnapshot(blank(), 5);

    expect(changed).toEqual([{ seq: 6, x: 3, y: 1, color: 9 }]);
    expect(state.colorAt(3, 1)).toBe(9);
  });

  it("drops held messages the fetched board already includes", () => {
    const state = new BoardState(4, 2);
    state.beginSync();
    state.receive({ seq: 4, x: 0, y: 0, color: 9 });

    // The fetched board is at seq 5 and already shows colour 2 at pixel 0.
    const changed = state.loadSnapshot(new Uint8Array([0x20, 0, 0, 0]), 5);

    expect(changed).toEqual([]);
    expect(state.colorAt(0, 0)).toBe(2);
  });

  it("starts holding again after a reconnect and replaces the board on the next load", () => {
    const state = loaded();
    state.receive({ seq: 1, x: 0, y: 0, color: 6 });

    state.beginSync();
    expect(state.isLoaded).toBe(false);
    state.receive({ seq: 3, x: 1, y: 0, color: 8 });
    state.loadSnapshot(new Uint8Array([0x10, 0, 0, 0]), 2);

    expect(state.colorAt(0, 0)).toBe(1);
    expect(state.colorAt(1, 0)).toBe(8);
  });

  it("ignores messages for positions outside the board", () => {
    const state = loaded();

    expect(state.receive({ seq: 1, x: 4, y: 0, color: 1 })).toBe(false);
    expect(state.receive({ seq: 2, x: 0, y: -1, color: 1 })).toBe(false);
  });

  describe("optimistic painting", () => {
    it("restores the old colour when the server refuses the pixel", () => {
      const state = loaded();
      state.receive({ seq: 1, x: 1, y: 1, color: 4 });

      const paint = state.paintOptimistically(1, 1, 9);
      expect(state.colorAt(1, 1)).toBe(9);

      expect(state.revert(paint)).toBe(4);
      expect(state.colorAt(1, 1)).toBe(4);
    });

    it("leaves a real update alone if one arrived before the refusal", () => {
      const state = loaded();

      const paint = state.paintOptimistically(1, 1, 9);
      state.receive({ seq: 2, x: 1, y: 1, color: 6 });

      expect(state.revert(paint)).toBeNull();
      expect(state.colorAt(1, 1)).toBe(6);
    });

    it("lets the server's confirmation win over an older broadcast that slipped in", () => {
      const state = loaded();

      state.paintOptimistically(0, 0, 9);
      state.receive({ seq: 3, x: 0, y: 0, color: 2 });

      expect(state.apply({ seq: 4, x: 0, y: 0, color: 9 })).toBe(true);
      expect(state.colorAt(0, 0)).toBe(9);
    });
  });
});
