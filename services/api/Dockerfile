# Multi-stage Bun build for the PixelHop leaderboard API.
# Critical: NODE_ENV is intentionally NOT set as a Coolify env var (would skip devDeps at install).
# It's set inside the runner stage only.

# ---- deps stage ----
FROM oven/bun:1.3-alpine AS deps
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

# ---- runner stage ----
FROM oven/bun:1.3-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# wget for healthcheck (alpine has it via busybox)
RUN apk add --no-cache curl

COPY --from=deps /app/node_modules ./node_modules
COPY package.json bun.lock* ./
COPY tsconfig.json drizzle.config.ts ./
COPY src ./src

EXPOSE 3000

# Run migrations on every boot, then start server.
# bunx invokes the locally-installed drizzle-kit binary.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost:${PORT}/v1/health || exit 1

CMD ["sh", "-c", "bunx drizzle-kit migrate && bun src/index.ts"]
