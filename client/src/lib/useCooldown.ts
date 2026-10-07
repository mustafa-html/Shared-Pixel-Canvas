import { useEffect, useState } from "react";

// Milliseconds left until `until`, updated ten times a second while it runs.
export function useCooldown(until: number): number {
  const [remaining, setRemaining] = useState(() => Math.max(0, until - Date.now()));

  useEffect(() => {
    const tick = () => setRemaining(Math.max(0, until - Date.now()));
    tick();
    if (until <= Date.now()) return;

    const timer = window.setInterval(() => {
      tick();
      if (until <= Date.now()) window.clearInterval(timer);
    }, 100);
    return () => window.clearInterval(timer);
  }, [until]);

  return remaining;
}
