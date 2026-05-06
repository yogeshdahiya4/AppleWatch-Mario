import { sql } from "drizzle-orm";
import {
  bigserial,
  boolean,
  customType,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";

// citext for case-insensitive nicknames
const citext = customType<{ data: string }>({
  dataType() {
    return "citext";
  },
});

export const devices = pgTable(
  "devices",
  {
    id: uuid("id").primaryKey(),
    nickname: citext("nickname").notNull(),
    // Per-device HMAC secret. Stored as raw hex; DB is internal-network-only.
    secret: text("secret").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex("devices_nickname_unique").on(t.nickname)],
);

export const scores = pgTable(
  "scores",
  {
    id: bigserial("id", { mode: "number" }).primaryKey(),
    deviceId: uuid("device_id")
      .notNull()
      .references(() => devices.id, { onDelete: "cascade" }),
    // "1-1" / "1-2" / "1-3" / "1-4" / "world1"
    level: text("level").notNull(),
    score: integer("score").notNull(),
    timeMs: integer("time_ms").notNull(),
    coins: integer("coins").notNull().default(0),
    worldCompleted: boolean("world_completed").notNull().default(false),
    submittedAt: timestamp("submitted_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    // per-level leaderboard read path
    index("scores_level_score_idx").on(t.level, t.score, t.timeMs),
    // global leaderboard reads only world-completed entries; partial index keeps it lean
    index("scores_global_idx").on(t.score, t.timeMs).where(sql`${t.worldCompleted} = true`),
    index("scores_device_idx").on(t.deviceId, t.submittedAt),
  ],
);

export const nonces = pgTable("nonces", {
  nonce: text("nonce").primaryKey(),
  deviceId: uuid("device_id")
    .notNull()
    .references(() => devices.id, { onDelete: "cascade" }),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
});

export type Device = typeof devices.$inferSelect;
export type NewDevice = typeof devices.$inferInsert;
export type Score = typeof scores.$inferSelect;
export type NewScore = typeof scores.$inferInsert;
