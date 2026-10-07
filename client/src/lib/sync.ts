import { createConsumer, type Consumer } from "@rails/actioncable";
import { getBoard } from "./api";
import type { BoardState, PixelMessage } from "./boardState";

export type SyncStatus = "loading" | "live" | "reconnecting" | "rebuilding";

type Handlers = {
  // The whole board was replaced: redraw everything.
  onBoard: () => void;
  // One pixel changed.
  onPixel: (message: PixelMessage) => void;
  onStatus: (status: SyncStatus) => void;
};

const RETRY_MS = 2000;

// Keeps a BoardState in step with the server. The order matters: subscribe
// first, then fetch. Fetching first would lose any pixel placed between the
// fetch and the subscription. The same steps run again after every reconnect.
export class BoardSync {
  private consumer: Consumer | null = null;
  private generation = 0;

  constructor(
    private readonly state: BoardState,
    private readonly handlers: Handlers,
  ) {}

  start(): void {
    this.handlers.onStatus("loading");
    this.consumer = createConsumer("/cable");
    this.consumer.subscriptions.create("BoardChannel", {
      connected: () => void this.resync(),
      disconnected: () => {
        this.generation++;
        this.state.beginSync();
        this.handlers.onStatus("reconnecting");
      },
      received: (message: PixelMessage) => {
        if (this.state.receive(message)) this.handlers.onPixel(message);
      },
    });
  }

  stop(): void {
    this.generation++;
    this.consumer?.disconnect();
    this.consumer = null;
  }

  // Fetches the board while live messages are held back. If the connection
  // drops and returns mid-fetch, the newer run wins and this one stops.
  private async resync(): Promise<void> {
    const generation = ++this.generation;
    this.state.beginSync();

    while (generation === this.generation) {
      let waitMs = RETRY_MS;
      try {
        const board = await getBoard();
        if (generation !== this.generation) return;

        if (board.kind === "ok") {
          this.state.loadSnapshot(board.bytes, board.seq);
          this.handlers.onBoard();
          this.handlers.onStatus("live");
          return;
        }

        this.handlers.onStatus("rebuilding");
        waitMs = board.retryAfterMs;
      } catch {
        if (generation !== this.generation) return;
        this.handlers.onStatus("reconnecting");
      }
      await new Promise((resolve) => setTimeout(resolve, waitMs));
    }
  }
}
