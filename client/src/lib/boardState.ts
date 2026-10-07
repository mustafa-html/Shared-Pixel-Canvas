import { unpackBoard } from "./bits";

export type PixelMessage = { seq: number; x: number; y: number; color: number; t?: number };

export type OptimisticPaint = { index: number; previousColor: number; seqAtPaint: number };

// The client's copy of the board, and the rules that keep it correct while
// live updates and full board fetches race each other:
//
//   1. Messages that arrive before the board has loaded are held back.
//   2. Every pixel remembers the sequence number of the last update applied
//      to it, starting at the sequence number of the fetched board.
//   3. A message is applied only if its number is higher than the one stored
//      for that pixel. Broadcasts can arrive out of order, and this keeps the
//      final colour right.
export class BoardState {
  readonly width: number;
  readonly height: number;
  colors: Uint8Array;

  private seqs: Uint32Array;
  private loaded = false;
  private held: PixelMessage[] = [];

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
    this.colors = new Uint8Array(width * height);
    this.seqs = new Uint32Array(width * height);
  }

  get isLoaded(): boolean {
    return this.loaded;
  }

  // Call when the socket connects, before fetching the board. From here until
  // loadSnapshot, incoming messages are held instead of applied.
  beginSync(): void {
    this.loaded = false;
    this.held = [];
  }

  // Replaces the board with a fetched copy, then applies the held messages
  // that are newer than it. Returns the pixels those messages changed.
  loadSnapshot(bytes: Uint8Array, seq: number): PixelMessage[] {
    this.colors = unpackBoard(bytes, this.width * this.height);
    this.seqs.fill(seq);
    this.loaded = true;

    const held = this.held;
    this.held = [];
    return held.filter((message) => this.apply(message));
  }

  // Handles a live message. Returns true if the board changed.
  receive(message: PixelMessage): boolean {
    if (!this.loaded) {
      this.held.push(message);
      return false;
    }
    return this.apply(message);
  }

  apply(message: PixelMessage): boolean {
    if (!this.contains(message.x, message.y)) return false;

    const index = this.indexOf(message.x, message.y);
    if (message.seq <= this.seqs[index]) return false;

    this.seqs[index] = message.seq;
    this.colors[index] = message.color;
    return true;
  }

  // Shows the user's own pixel before the server has answered.
  paintOptimistically(x: number, y: number, color: number): OptimisticPaint {
    const index = this.indexOf(x, y);
    const paint = { index, previousColor: this.colors[index], seqAtPaint: this.seqs[index] };
    this.colors[index] = color;
    return paint;
  }

  // Undoes an optimistic paint the server refused. If a real update reached
  // that pixel in the meantime it is left alone. Returns the colour restored,
  // or null when nothing needed undoing.
  revert(paint: OptimisticPaint): number | null {
    if (this.seqs[paint.index] !== paint.seqAtPaint) return null;

    this.colors[paint.index] = paint.previousColor;
    return paint.previousColor;
  }

  colorAt(x: number, y: number): number {
    return this.colors[this.indexOf(x, y)];
  }

  contains(x: number, y: number): boolean {
    return Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x < this.width && y >= 0 && y < this.height;
  }

  private indexOf(x: number, y: number): number {
    return y * this.width + x;
  }
}
