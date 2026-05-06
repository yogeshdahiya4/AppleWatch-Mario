import { Hono } from "hono";
import { sql } from "drizzle-orm";
import { db } from "../db/client.ts";

export const healthRoute = new Hono();

healthRoute.get("/health", async (c) => {
  const t0 = performance.now();
  try {
    const [row] = await db.execute<{ ok: number }>(sql`select 1 as ok`);
    const dbMs = Math.round(performance.now() - t0);
    return c.json({ ok: true, version: process.env.GIT_SHA ?? "dev", db_ms: dbMs, db: row?.ok === 1 });
  } catch (err) {
    return c.json({ ok: false, error: (err as Error).message }, 503);
  }
});
