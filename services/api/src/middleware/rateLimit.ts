import type { MiddlewareHandler } from "hono";

// Token-bucket rate limiter, keyed by device id (or IP fallback).
// In-memory: fine for a single instance. If we ever scale horizontally,
// swap in Postgres-backed leaky bucket or Redis.

type Bucket = { tokens: number; lastRefillMs: number };

interface Options {
  capacity: number; // max tokens
  refillPerSec: number; // tokens added per second
  keyFn?: (c: { req: { header: (n: string) => string | undefined } }) => string;
}

export function rateLimit(opts: Options): MiddlewareHandler {
  const buckets = new Map<string, Bucket>();
  const { capacity, refillPerSec } = opts;
  const keyFn =
    opts.keyFn ??
    ((c) => c.req.header("x-device-id") ?? c.req.header("cf-connecting-ip") ?? "anon");

  return async (c, next) => {
    const key = keyFn(c);
    const now = Date.now();
    let b = buckets.get(key);
    if (!b) {
      b = { tokens: capacity, lastRefillMs: now };
      buckets.set(key, b);
    }
    const elapsedSec = (now - b.lastRefillMs) / 1000;
    b.tokens = Math.min(capacity, b.tokens + elapsedSec * refillPerSec);
    b.lastRefillMs = now;
    if (b.tokens < 1) {
      const retryAfter = Math.ceil((1 - b.tokens) / refillPerSec);
      c.header("Retry-After", retryAfter.toString());
      return c.json({ error: "rate_limited", retry_after: retryAfter }, 429);
    }
    b.tokens -= 1;
    await next();
  };
}

// Periodic prune so the map doesn't grow unbounded
let pruneTimer: ReturnType<typeof setInterval> | null = null;
export function startRateLimitPruner() {
  if (pruneTimer) return;
  // we can't access bucket maps from here without globals; this is a no-op shim
  // to remind us where to wire pruning if we move to a shared store.
  pruneTimer = setInterval(() => {}, 60_000);
}
