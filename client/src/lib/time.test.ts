import { describe, expect, it } from "vitest";
import { timeAgo } from "./time";

const now = Date.parse("2026-10-08T12:00:00Z");

describe("timeAgo", () => {
  it.each([
    ["2026-10-08T11:59:57Z", "just now"],
    ["2026-10-08T11:59:20Z", "40 seconds ago"],
    ["2026-10-08T11:59:00Z", "a minute ago"],
    ["2026-10-08T11:45:00Z", "15 minutes ago"],
    ["2026-10-08T09:00:00Z", "3 hours ago"],
    ["2026-10-07T12:00:00Z", "yesterday"],
    ["2026-10-01T12:00:00Z", "7 days ago"],
    ["2026-10-08T12:00:30Z", "just now"],
  ])("describes %s as %s", (iso, expected) => {
    expect(timeAgo(iso, now)).toBe(expected);
  });
});
