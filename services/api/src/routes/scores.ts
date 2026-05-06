import { Hono } from "hono";
import { z } from "zod";
import { db, schema } from "../db/client.ts";
import { parseRawJson, requireSignedRequest } from "../middleware/hmac.ts";
import { rateLimit } from "../middleware/rateLimit.ts";

export const scoresRoute = new Hono();

const LEVELS = ["1-1", "1-2", "1-3", "1-4", "world1"] as const;

// Per-level sanity caps — anything beyond these is rejected as cheat.
// These are upper bounds with a ~2x buffer over reasonable max.
const SCORE_CAPS: Record<(typeof LEVELS)[number], number> = {
  "1-1": 50_000,
  "1-2": 50_000,
  "1-3": 60_000,
  "1-4": 80_000,
  world1: 250_000,
};
// Minimum credible time per level in ms (faster than this = TAS / cheat).
const TIME_FLOORS: Record<(typeof LEVELS)[number], number> = {
  "1-1": 12_000,
  "1-2": 14_000,
  "1-3": 16_000,
  "1-4": 18_000,
  world1: 60_000,
};

const SubmitBody = z.object({
  level: z.enum(LEVELS),
  score: z.number().int().min(0),
  time_ms: z.number().int().positive(),
  coins: z.number().int().min(0).max(999),
  world_completed: z.boolean(),
});

// 6 score submissions per minute per device — generous for retries, tight for spam
scoresRoute.post(
  "/scores",
  rateLimit({ capacity: 6, refillPerSec: 6 / 60 }),
  requireSignedRequest,
  async (c) => {
    const parsed = SubmitBody.safeParse(parseRawJson(c));
    if (!parsed.success) {
      return c.json({ error: "bad_payload", issues: parsed.error.issues }, 400);
    }
    const { level, score, time_ms, coins, world_completed } = parsed.data;

    if (score > SCORE_CAPS[level]) {
      return c.json({ error: "score_implausible", cap: SCORE_CAPS[level] }, 422);
    }
    if (time_ms < TIME_FLOORS[level]) {
      return c.json({ error: "time_implausible", floor: TIME_FLOORS[level] }, 422);
    }
    // world_completed only valid on the aggregate "world1" submission
    if (world_completed && level !== "world1") {
      return c.json({ error: "world_completed_only_on_world1" }, 422);
    }

    const device = c.get("device");
    const [inserted] = await db
      .insert(schema.scores)
      .values({
        deviceId: device.deviceId,
        level,
        score,
        timeMs: time_ms,
        coins,
        worldCompleted: world_completed,
      })
      .returning({ id: schema.scores.id, submittedAt: schema.scores.submittedAt });

    return c.json(
      { id: inserted!.id, submitted_at: inserted!.submittedAt, nickname: device.nickname },
      201,
    );
  },
);
