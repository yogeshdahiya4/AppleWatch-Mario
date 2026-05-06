import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { secureHeaders } from "hono/secure-headers";
import { healthRoute } from "./routes/health.ts";
import { devicesRoute } from "./routes/devices.ts";
import { scoresRoute } from "./routes/scores.ts";
import { leaderboardRoute } from "./routes/leaderboard.ts";
import { env } from "./env.ts";

const app = new Hono();

app.use(logger());
app.use(secureHeaders());
app.use(
  cors({
    // Watch app uses URLSession with no Origin header; we keep CORS open
    // so that browser-based ops dashboards (curl from the user's laptop) work.
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "X-Device-Id", "X-Timestamp", "X-Nonce", "X-Sig"],
    maxAge: 86_400,
  }),
);

app.get("/", (c) =>
  c.json({
    service: "pixelhop-api",
    version: process.env.GIT_SHA ?? "dev",
    docs: "see README in repo: yogeshdahiya4/AppleWatch-Mario",
  }),
);

app.route("/v1", healthRoute);
app.route("/v1", devicesRoute);
app.route("/v1", scoresRoute);
app.route("/v1", leaderboardRoute);

app.onError((err, c) => {
  console.error("[error]", err);
  return c.json({ error: "internal", message: err.message }, 500);
});

app.notFound((c) => c.json({ error: "not_found", path: c.req.path }, 404));

const port = env.PORT;
console.log(`pixelhop-api listening on :${port} (${env.NODE_ENV})`);

export default {
  port,
  fetch: app.fetch,
  idleTimeout: 30,
};
