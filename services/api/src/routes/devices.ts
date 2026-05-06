import { randomBytes } from "node:crypto";
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db, schema } from "../db/client.ts";
import { rateLimit } from "../middleware/rateLimit.ts";

export const devicesRoute = new Hono();

const RegisterBody = z.object({
  device_id: z.string().uuid(),
  nickname: z
    .string()
    .min(2)
    .max(16)
    .regex(/^[A-Za-z0-9_\-.]+$/, "nickname: letters, digits, _ - . only"),
});

// Anti-abuse: 1 registration per ~60s per device id; 5 burst
devicesRoute.post(
  "/devices",
  rateLimit({ capacity: 5, refillPerSec: 1 / 60, keyFn: (c) => c.req.header("x-device-id") ?? "anon" }),
  zValidator("json", RegisterBody),
  async (c) => {
    const { device_id, nickname } = c.req.valid("json");

    // If device already exists, refuse to overwrite (would leak others' identity).
    const existing = await db.query.devices.findFirst({ where: eq(schema.devices.id, device_id) });
    if (existing) {
      return c.json({ error: "device_already_registered" }, 409);
    }

    // Nickname uniqueness check (citext)
    const taken = await db.query.devices.findFirst({ where: eq(schema.devices.nickname, nickname) });
    if (taken) {
      return c.json({ error: "nickname_taken" }, 409);
    }

    const secret = randomBytes(32).toString("hex");
    await db.insert(schema.devices).values({ id: device_id, nickname, secret });

    return c.json({ device_id, nickname, secret }, 201);
  },
);

// Probe: does a nickname exist?  Used by the watch app to validate before submit.
devicesRoute.get("/devices/nickname-available/:nickname", async (c) => {
  const nick = c.req.param("nickname");
  const taken = await db.query.devices.findFirst({ where: eq(schema.devices.nickname, nick) });
  return c.json({ available: !taken });
});
