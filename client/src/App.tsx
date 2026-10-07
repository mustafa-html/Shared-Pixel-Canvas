import { useCallback, useEffect, useRef, useState } from "react";
import { getPixelInfo, getSession, getStats, placePixel, type PixelInfo, type Session, type Stats } from "./lib/api";
import { BoardState } from "./lib/boardState";
import { BoardSync, type SyncStatus } from "./lib/sync";
import { timeAgo } from "./lib/time";
import { useCooldown } from "./lib/useCooldown";
import { BoardView, type Point } from "./lib/view";

// Shared between React's development double-render and real mounts, so the
// first page load creates one guest, not two.
let sessionRequest: Promise<Session> | null = null;
function loadSession(): Promise<Session> {
  sessionRequest ??= getSession().catch((error) => {
    sessionRequest = null;
    throw error;
  });
  return sessionRequest;
}

export function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    loadSession()
      .then((loaded) => !cancelled && setSession(loaded))
      .catch(() => !cancelled && setFailed(true));
    return () => {
      cancelled = true;
    };
  }, []);

  if (failed) {
    return (
      <div className="notice-page">
        <p>The canvas could not be reached.</p>
        <button type="button" className="button" onClick={() => window.location.reload()}>
          Try again
        </button>
      </div>
    );
  }

  if (!session) return <div className="notice-page">Loading the canvas…</div>;

  return <Board session={session} />;
}

type Info = { kind: "none" } | { kind: "loading" } | { kind: "empty" } | { kind: "placed"; info: PixelInfo };

const STATUS_TEXT: Record<SyncStatus, string> = {
  loading: "Loading the board…",
  live: "Live",
  reconnecting: "Reconnecting…",
  rebuilding: "Restoring the board…",
};

function Board({ session }: { session: Session }) {
  const { width, height, palette, cooldown_ms: cooldownMs } = session.board;

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stateRef = useRef<BoardState | null>(null);
  const viewRef = useRef<BoardView | null>(null);
  const selectedRef = useRef<Point | null>(null);
  const placeRef = useRef<() => void>(() => {});

  const [status, setStatus] = useState<SyncStatus>("loading");
  const [color, setColor] = useState(5);
  const [selected, setSelected] = useState<Point | null>(null);
  const [info, setInfo] = useState<Info>({ kind: "none" });
  const [infoVersion, setInfoVersion] = useState(0);
  const [stats, setStats] = useState<Stats | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [cooldownUntil, setCooldownUntil] = useState(() => Date.now() + session.cooldown_remaining_ms);
  const remaining = useCooldown(cooldownUntil);

  // The board, its renderer and the live connection.
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const state = new BoardState(width, height);
    const view = new BoardView(canvas, width, height, palette, {
      onSelect: setSelected,
      onConfirm: () => placeRef.current(),
    });
    const sync = new BoardSync(state, {
      onBoard: () => view.setBoard(state.colors),
      onPixel: (pixel) => {
        view.setPixel(pixel.x, pixel.y, pixel.color);
        setStats((current) => current && { ...current, total_placements: current.total_placements + 1 });
        const watched = selectedRef.current;
        if (watched && watched.x === pixel.x && watched.y === pixel.y) setInfoVersion((version) => version + 1);
      },
      onStatus: setStatus,
    });

    stateRef.current = state;
    viewRef.current = view;
    sync.start();

    return () => {
      sync.stop();
      view.destroy();
      stateRef.current = null;
      viewRef.current = null;
    };
  }, [width, height, palette]);

  // Who painted the selected pixel.
  useEffect(() => {
    selectedRef.current = selected;
    viewRef.current?.setSelection(selected);
    if (!selected) {
      setInfo({ kind: "none" });
      return;
    }

    let cancelled = false;
    setInfo((current) => (current.kind === "placed" ? current : { kind: "loading" }));
    getPixelInfo(selected.x, selected.y)
      .then((found) => !cancelled && setInfo(found ? { kind: "placed", info: found } : { kind: "empty" }))
      .catch(() => !cancelled && setInfo({ kind: "none" }));
    return () => {
      cancelled = true;
    };
  }, [selected, infoVersion]);

  useEffect(() => {
    const refresh = () => getStats().then(setStats).catch(() => {});
    refresh();
    const timer = window.setInterval(refresh, 20_000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!message) return;
    const timer = window.setTimeout(() => setMessage(null), 5000);
    return () => window.clearTimeout(timer);
  }, [message]);

  const place = useCallback(async () => {
    const state = stateRef.current;
    const view = viewRef.current;
    if (!state || !view || !selected || Date.now() < cooldownUntil) return;

    const { x, y } = selected;

    // Show the pixel at once, then let the server confirm or refuse it.
    const paint = state.paintOptimistically(x, y, color);
    view.setPixel(x, y, color);
    setCooldownUntil(Date.now() + cooldownMs);

    const undo = () => {
      const restored = state.revert(paint);
      if (restored !== null) view.setPixel(x, y, restored);
    };

    try {
      const result = await placePixel(x, y, color);

      if (result.kind === "placed") {
        if (state.apply({ seq: result.seq, x, y, color })) view.setPixel(x, y, color);
        setCooldownUntil(Date.now() + result.cooldownMs);
        setInfoVersion((version) => version + 1);
        return;
      }

      undo();
      switch (result.kind) {
        case "cooldown":
          setCooldownUntil(Date.now() + result.retryAfterMs);
          break;
        case "rate_limited":
          setCooldownUntil(Date.now() + result.retryAfterMs);
          setMessage("Too many pixels from your network just now. Try again in a few seconds.");
          break;
        case "rebuilding":
          setCooldownUntil(0);
          setMessage("The board is being restored. Try again in a moment.");
          break;
        case "no_session":
          setCooldownUntil(0);
          setMessage("Your session has ended. Reload the page to keep painting.");
          break;
        case "invalid":
          setCooldownUntil(0);
          setMessage("That pixel is outside the board.");
          break;
      }
    } catch {
      undo();
      setCooldownUntil(0);
      setMessage("The pixel was not placed because the server could not be reached.");
    }
  }, [selected, color, cooldownUntil, cooldownMs]);

  placeRef.current = () => void place();

  const waiting = remaining > 0;
  const buttonLabel = waiting ? `Wait ${Math.ceil(remaining / 1000)}s` : selected ? "Place pixel" : "Pick a pixel";

  return (
    <main className="app">
      <canvas
        ref={canvasRef}
        className="board"
        tabIndex={0}
        role="application"
        aria-label={`Shared canvas, ${width} by ${height} pixels. Use the arrow keys to move the selection and Enter to place a pixel.`}
      />

      <header className="panel masthead">
        <h1>Shared Pixel Canvas</h1>
        <p>
          {stats
            ? `${stats.total_placements.toLocaleString()} pixels placed by ${stats.total_users.toLocaleString()} people`
            : "One pixel at a time, together"}
        </p>
      </header>

      <div className="controls">
        <span className={`panel status status-${status}`} role="status">
          {STATUS_TEXT[status]}
        </span>
        <div className="panel zoom">
          <button type="button" aria-label="Zoom in" onClick={() => viewRef.current?.zoomBy(1.6)}>
            +
          </button>
          <button type="button" aria-label="Zoom out" onClick={() => viewRef.current?.zoomBy(1 / 1.6)}>
            −
          </button>
          <button type="button" className="zoom-fit" onClick={() => viewRef.current?.fit()}>
            Fit
          </button>
        </div>
      </div>

      <section className="panel tray" aria-label="Paint tray">
        <div className="swatches" role="radiogroup" aria-label="Colour">
          {palette.map((hex, index) => (
            <button
              key={hex}
              type="button"
              role="radio"
              aria-checked={index === color}
              aria-label={`Colour ${index + 1} of ${palette.length}, ${hex}`}
              className={index === color ? "swatch swatch-selected" : "swatch"}
              style={{ backgroundColor: hex }}
              onClick={() => setColor(index)}
            />
          ))}
        </div>

        <div className="action">
          <p className="selection" aria-live="polite">
            {message ?? describeSelection(selected, info, session.user.display_name)}
          </p>
          <button type="button" className="button place" disabled={waiting || !selected} onClick={() => void place()}>
            <span className="place-chip" style={{ backgroundColor: palette[color] }} />
            {buttonLabel}
            {waiting && (
              <span
                className="place-progress"
                style={{ width: `${Math.min(100, (remaining / cooldownMs) * 100)}%` }}
              />
            )}
          </button>
        </div>
      </section>
    </main>
  );
}

function describeSelection(selected: Point | null, info: Info, ownName: string): string {
  if (!selected) return `You are ${ownName}. Pick a pixel on the board, then a colour.`;

  const position = `Pixel ${selected.x}, ${selected.y}`;
  switch (info.kind) {
    case "placed": {
      // Still showing the previous pixel's answer while this one loads.
      if (info.info.x !== selected.x || info.info.y !== selected.y) return position;

      const painter = info.info.placed_by === ownName ? "you" : info.info.placed_by;
      return `${position}: painted by ${painter}, ${timeAgo(info.info.placed_at)}`;
    }
    case "empty":
      return `${position}: nobody has painted here yet`;
    default:
      return position;
  }
}
