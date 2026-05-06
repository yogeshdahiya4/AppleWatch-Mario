import { createHmac, timingSafeEqual } from "node:crypto";
import { eq } from "drizzle-orm";
import type { MiddlewareHandler } from "hono";
import { db, schema } from "../db/client.ts";

const TIMESTAMP_WINDOW_SECONDS = 300; // ±5 min
const NONCE_TTL_SECONDS = 600;

type Verified = { deviceId: string; secret: string; nickname: string };

declare module "hono" {
  interface ContextVariableMap {
    device: Verified;
  }
}

/**
 * verify per-device HMAC headers:
 *   X-Device-Id    uuid
 *   X-Timestamp    unix epoch seconds
 *   X-Nonce        random hex (>=16 chars)
 *   X-Sig          hex(HMAC-SHA256(secret, method\npath\nts\nnonce\nbody))
 */
export const requireSignedRequest: MiddlewareHandler = async (c, next) => {
  const deviceId = c.req.header("x-device-id");
  const ts = c.req.header("x-timestamp");
  const nonce = c.req.header("x-nonce");
  const sig = c.req.header("x-sig");

  if (!deviceId || !ts || !nonce || !sig) {
    return c.json({ error: "missing_signature_headers" }, 401);
  }
  if (!/^[0-9a-f-]{36}$/i.test(deviceId)) {
    return c.json({ error: "bad_device_id" }, 400);
  }
  if (nonce.length < 16 || nonce.length > 64 || !/^[0-9a-f]+$/i.test(nonce)) {
    return c.json({ error: "bad_nonce" }, 400);
  }

  const tsNum = Number(ts);
  if (!Number.isFinite(tsNum)) {
    return c.json({ error: "bad_timestamp" }, 400);
  }
  const drift = Math.abs(Math.floor(Date.now() / 1000) - tsNum);
  if (drift > TIMESTAMP_WINDOW_SECONDS) {
    return c.json({ error: "stale_timestamp", drift }, 401);
  }

  const device = await db.query.devices.findFirst({
    where: eq(schema.devices.id, deviceId),
  });
  if (!device) {
    return c.json({ error: "unknown_device" }, 401);
  }

  const rawBody = await c.req.text();
  const method = c.req.method.toUpperCase();
  const path = new URL(c.req.url).pathname;
  const message = `${method}\n${path}\n${ts}\n${nonce}\n${rawBody}`;
  const expected = createHmac("sha256", device.secret).update(message).digest();
  let provided: Buffer;
  try {
    provided = Buffer.from(sig, "hex");
  } catch {
    return c.json({ error: "bad_signature_encoding" }, 400);
  }
  if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
    return c.json({ error: "bad_signature" }, 401);
  }

  // replay protection — insert nonce; rely on PK conflict to detect re-use
  try {
    await db.insert(schema.nonces).values({
      nonce,
      deviceId,
      expiresAt: new Date(Date.now() + NONCE_TTL_SECONDS * 1000),
    });
  } catch {
    return c.json({ error: "replay_detected" }, 401);
  }

  // make rawBody available to the handler since we already consumed it
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (c.req as any).rawBody = rawBody;
  c.set("device", { deviceId: device.id, secret: device.secret, nickname: device.nickname });

  // Touch lastSeenAt opportunistically (no need to await)
  void db
    .update(schema.devices)
    .set({ lastSeenAt: new Date() })
    .where(eq(schema.devices.id, deviceId))
    .catch(() => {});

  await next();
};

// We stash the raw body on the request after consuming it; this helper reads it back.
// Using `any` here is intentional — Hono's typed request shape doesn't expose an extension point.
export function parseRawJson<T>(c: unknown): T | null {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const raw = (c as any)?.req?.rawBody;
  if (typeof raw !== "string") return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}
