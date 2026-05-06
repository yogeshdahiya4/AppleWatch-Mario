import { Hono } from "hono";
import { and, desc, asc, eq, sql } from "drizzle-orm";
import { db, schema } from "../db/client.ts";

export const leaderboardRoute = new Hono();

const LEVELS = new Set(["1-1", "1-2", "1-3", "1-4", "world1"]);

// GET /v1/leaderboard/:level?limit=100&device=<uuid>
leaderboardRoute.get("/leaderboard/:level", async (c) => {
  const level = c.req.param("level");
  if (!LEVELS.has(level)) {
    return c.json({ error: "unknown_level" }, 404);
  }
  const limit = Math.min(100, Math.max(1, Number(c.req.query("limit") ?? 100)));
  const deviceId = c.req.query("device");

  // For each device, take their best (max score, then min time) and rank globally.
  const top = await db.execute<{
    rank: number;
    device_id: string;
    nickname: string;
    score: number;
    time_ms: number;
    coins: number;
    submitted_at: Date;
  }>(sql`
    with best as (
      select distinct on (s.device_id)
        s.device_id,
        s.score,
        s.time_ms,
        s.coins,
        s.submitted_at
      from ${schema.scores} s
      where s.level = ${level}
      order by s.device_id, s.score desc, s.time_ms asc, s.submitted_at asc
    )
    select
      row_number() over (order by b.score desc, b.time_ms asc) as rank,
      b.device_id,
      d.nickname,
      b.score,
      b.time_ms,
      b.coins,
      b.submitted_at
    from best b
    join ${schema.devices} d on d.id = b.device_id
    order by rank
    limit ${limit}
  `);

  let me = null;
  if (deviceId) {
    const meRows = await db.execute<{
      rank: number;
      score: number;
      time_ms: number;
    }>(sql`
      with best as (
        select distinct on (s.device_id)
          s.device_id, s.score, s.time_ms
        from ${schema.scores} s
        where s.level = ${level}
        order by s.device_id, s.score desc, s.time_ms asc, s.submitted_at asc
      ), ranked as (
        select b.device_id, b.score, b.time_ms,
               row_number() over (order by b.score desc, b.time_ms asc) as rank
        from best b
      )
      select rank, score, time_ms from ranked where device_id = ${deviceId}
    `);
    me = meRows[0] ?? null;
  }

  return c.json({ level, top, me });
});

// GET /v1/leaderboard/global  (only world-completed)
leaderboardRoute.get("/leaderboard", async (c) => {
  const limit = Math.min(100, Math.max(1, Number(c.req.query("limit") ?? 100)));
  const top = await db
    .select({
      deviceId: schema.scores.deviceId,
      nickname: schema.devices.nickname,
      score: schema.scores.score,
      timeMs: schema.scores.timeMs,
      submittedAt: schema.scores.submittedAt,
    })
    .from(schema.scores)
    .innerJoin(schema.devices, eq(schema.devices.id, schema.scores.deviceId))
    .where(and(eq(schema.scores.level, "world1"), eq(schema.scores.worldCompleted, true)))
    .orderBy(desc(schema.scores.score), asc(schema.scores.timeMs))
    .limit(limit);

  return c.json({ scope: "global", top });
});
