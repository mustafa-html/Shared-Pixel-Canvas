export type Session = {
  user: { id: number; display_name: string };
  cooldown_remaining_ms: number;
  board: { width: number; height: number; palette: string[]; cooldown_ms: number };
};

export type PixelInfo = { x: number; y: number; color: number; seq: number; placed_by: string; placed_at: string };

export type Stats = { total_placements: number; total_users: number };

export type BoardFetch = { kind: "ok"; bytes: Uint8Array; seq: number } | { kind: "rebuilding"; retryAfterMs: number };

export type PlaceResult =
  | { kind: "placed"; seq: number; cooldownMs: number }
  | { kind: "cooldown"; retryAfterMs: number }
  | { kind: "rate_limited"; retryAfterMs: number }
  | { kind: "rebuilding" }
  | { kind: "no_session" }
  | { kind: "invalid" };

async function json<T>(response: Response): Promise<T> {
  return (await response.json()) as T;
}

export async function getSession(): Promise<Session> {
  const response = await fetch("/api/session");
  if (!response.ok) throw new Error(`session request failed with ${response.status}`);
  return json<Session>(response);
}

export async function getBoard(): Promise<BoardFetch> {
  const response = await fetch("/api/board", { cache: "no-store" });
  if (response.status === 503) return { kind: "rebuilding", retryAfterMs: 2000 };
  if (!response.ok) throw new Error(`board request failed with ${response.status}`);

  const seq = Number(response.headers.get("X-Board-Seq"));
  if (!Number.isFinite(seq)) throw new Error("board response has no sequence number");

  return { kind: "ok", bytes: new Uint8Array(await response.arrayBuffer()), seq };
}

export async function placePixel(x: number, y: number, color: number): Promise<PlaceResult> {
  const response = await fetch("/api/pixels", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ x, y, color }),
  });

  switch (response.status) {
    case 201: {
      const body = await json<{ seq: number; cooldown_ms: number }>(response);
      return { kind: "placed", seq: body.seq, cooldownMs: body.cooldown_ms };
    }
    case 429: {
      const body = await json<{ error: string; retry_after_ms: number }>(response);
      return { kind: body.error === "cooldown" ? "cooldown" : "rate_limited", retryAfterMs: body.retry_after_ms };
    }
    case 401:
      return { kind: "no_session" };
    case 422:
      return { kind: "invalid" };
    case 503:
      return { kind: "rebuilding" };
    default:
      throw new Error(`placement failed with ${response.status}`);
  }
}

export async function getPixelInfo(x: number, y: number): Promise<PixelInfo | null> {
  const response = await fetch(`/api/pixels/${x}/${y}`);
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`pixel request failed with ${response.status}`);
  return json<PixelInfo>(response);
}

export async function getStats(): Promise<Stats> {
  const response = await fetch("/api/stats");
  if (!response.ok) throw new Error(`stats request failed with ${response.status}`);
  return json<Stats>(response);
}
