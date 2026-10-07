// Load test for the placement path. Each virtual user behaves like one open
// browser tab: it gets a guest session, holds a WebSocket open, and places a
// pixel every cooldown.
//
//   k6 run -e SCENARIO=baseline loadtest/placements.js
//   k6 run -e SCENARIO=target   loadtest/placements.js
//   k6 run -e SCENARIO=spike    loadtest/placements.js
//
// Start the API with RATE_LIMIT_DISABLED=1 first: every virtual user shares
// one address, so the per-address limits would otherwise refuse most of them.
// Afterwards run `rake board:check`; it must report zero differences.

import { check } from "k6";
import http from "k6/http";
import { Counter, Rate, Trend } from "k6/metrics";
import ws from "k6/ws";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";
const WS_URL = `${BASE_URL.replace(/^http/, "ws")}/cable`;
const SCENARIO = __ENV.SCENARIO || "baseline";

// Placements land in a small square so that users overwrite each other.
const REGION = Number(__ENV.REGION || 64);
// How long one virtual user keeps its socket open before reconnecting.
const SESSION_SECONDS = Number(__ENV.SESSION_SECONDS || 30);

const SCENARIOS = {
  baseline: { stages: [{ duration: "10s", target: 50 }, { duration: "110s", target: 50 }] },
  target: { stages: [{ duration: "20s", target: 200 }, { duration: "280s", target: 200 }] },
  spike: { stages: [{ duration: "30s", target: 1000 }, { duration: "60s", target: 1000 }] },
};

if (!SCENARIOS[SCENARIO]) throw new Error(`unknown SCENARIO "${SCENARIO}"`);

export const options = {
  // Keep each virtual user's guest cookie from one iteration to the next.
  noCookiesReset: true,
  scenarios: {
    [SCENARIO]: {
      executor: "ramping-vus",
      startVUs: 0,
      gracefulStop: "10s",
      gracefulRampDown: "10s",
      ...SCENARIOS[SCENARIO],
    },
  },
  summaryTrendStats: ["avg", "min", "med", "p(95)", "p(99)", "max"],
  thresholds: {
    server_errors: ["rate==0"],
  },
};

// POST /api/pixels latency for accepted placements only.
const placeLatency = new Trend("place_latency_ms", true);
// From the moment the server broadcast a pixel to its arrival on a socket.
// Only meaningful when k6 and the API run on the same clock.
const broadcastDelay = new Trend("broadcast_delay_ms", true);
const placed = new Counter("placements_accepted");
const refused = new Counter("placements_on_cooldown");
const received = new Counter("broadcasts_received");
const serverErrors = new Rate("server_errors");

const SUBSCRIBE = JSON.stringify({ command: "subscribe", identifier: JSON.stringify({ channel: "BoardChannel" }) });

export default function () {
  const session = http.get(`${BASE_URL}/api/session`);
  serverErrors.add(session.status >= 500);
  if (!check(session, { "session is 200": (r) => r.status === 200 })) return;

  const { board, cooldown_remaining_ms: cooldownLeft } = session.json();
  const side = Math.min(REGION, board.width, board.height);

  const placeOne = () => {
    const body = JSON.stringify({
      x: Math.floor(Math.random() * side),
      y: Math.floor(Math.random() * side),
      color: Math.floor(Math.random() * board.palette.length),
    });
    const response = http.post(`${BASE_URL}/api/pixels`, body, { headers: { "Content-Type": "application/json" } });

    serverErrors.add(response.status >= 500);
    if (response.status === 201) {
      placed.add(1);
      placeLatency.add(response.timings.duration);
    } else if (response.status === 429) {
      refused.add(1);
    }
    check(response, { "placement is 201 or 429": (r) => r.status === 201 || r.status === 429 });
  };

  // Action Cable only accepts a socket whose Origin matches the host.
  const result = ws.connect(WS_URL, { headers: { Origin: BASE_URL } }, (socket) => {
    socket.on("open", () => socket.send(SUBSCRIBE));

    socket.on("message", (raw) => {
      const frame = JSON.parse(raw);

      if (frame.type === "confirm_subscription") {
        // Spread users out so they do not all place in the same instant.
        const firstIn = cooldownLeft + Math.random() * board.cooldown_ms;
        socket.setTimeout(() => {
          placeOne();
          socket.setInterval(placeOne, board.cooldown_ms + 50);
        }, firstIn);
        return;
      }

      if (frame.message && typeof frame.message.t === "number") {
        received.add(1);
        broadcastDelay.add(Date.now() - frame.message.t);
      }
    });

    socket.setTimeout(() => socket.close(), SESSION_SECONDS * 1000);
  });

  check(result, { "socket upgraded": (r) => r && r.status === 101 });
}
