# Security model — PixelHop API

## Threat model

This is a small leaderboard for a side-project game. The threats we worry about:

1. **Casual cheating** — submitting impossibly high scores via curl
2. **Replay attacks** — re-submitting a captured request to inflate own score
3. **Nickname squatting** — registering many devices to lock common nicknames
4. **Server-side spam / DoS** — flooding submissions

What we **don't** defend against (out of scope for v1):
- A motivated attacker who reverse-engineers the watch app to extract
  the per-device secret. The secret is on the device — if you have
  the device, you have the secret. The right defense for that is
  server-authoritative gameplay (we re-simulate the run server-side and
  reject scores that don't match), which is over-engineered for v1.
- Stolen device — losing your watch means losing your leaderboard entry.

## Defenses

### Per-device HMAC signing

Every state-changing request from the watch (`POST /v1/scores`) is
signed with a per-device 32-byte secret:

```
sig = HMAC-SHA256(secret, METHOD || "\n" || PATH || "\n" || TIMESTAMP || "\n" || NONCE || "\n" || BODY)
```

The secret is generated server-side at `POST /v1/devices` time and
returned exactly once. It's stored in the watch's Keychain
(`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). The server stores
it in the `devices.secret` column of an internal-network-only Postgres
database.

Verification (in `src/middleware/hmac.ts`):
- **Header presence:** require `X-Device-Id`, `X-Timestamp`, `X-Nonce`, `X-Sig`
- **Timestamp window:** ±300s. Stale stamps → 401.
- **Constant-time compare:** `timingSafeEqual` so we don't leak signature
  validity through response timing.

### Replay protection (nonces)

Each signed request must include a fresh `X-Nonce`. Server inserts the
nonce into the `nonces` table. Primary key violation = replay → 401.

A periodic cleanup job (cron-style or app-startup hook) prunes nonces
older than `expiresAt` (10 min). For a low-volume leaderboard this is
unnecessary in practice — the table will reach steady state at a few
thousand rows.

### Rate limiting

Token-bucket per device (`X-Device-Id` header). Configured per-route
in the route file:

| Route | Capacity | Refill rate | Why |
|---|---|---|---|
| `POST /v1/devices` | 5 | 1 / 60s | block nickname squatting flood |
| `POST /v1/scores`  | 6 | 6 / 60s | normal play tops out at 4–5 submits / world run |

In-memory buckets — fine for single-instance deploy. If we scale
horizontally, swap in a Redis or Postgres-backed token bucket.

### Score validity caps

`POST /v1/scores` rejects implausible payloads:

- `score > SCORE_CAPS[level]` → 422 (~2x reasonable max)
- `time_ms < TIME_FLOORS[level]` → 422 (faster than humanly possible)
- `world_completed: true` only allowed when `level == "world1"`

These don't stop a determined cheater (they could just submit a
score = cap-1) but they make casual API tampering visible. Combined
with the per-device HMAC, an attacker would need to know both the
secret (device-bound) AND craft a valid-looking score.

### Nickname uniqueness

`devices.nickname` is a `citext` column with a unique index. Case-insensitive
match. Server returns 409 on collision.

### Database access

- Postgres is on the internal Coolify network — never exposed publicly
- The `DATABASE_URL` is set as a runtime-only env var (`is_buildtime: false`)
  so it's not baked into the Docker image
- Drizzle uses parameterized queries throughout — no string interpolation
  into SQL

## Secrets handling

- `HMAC_SERVER_SECRET` (currently used only as documentation; per-device
  secrets do the actual signing): set as runtime env var in Coolify; copy
  saved locally in `.coolify-secrets.json` (gitignored, chmod 600)
- Per-device secrets: stored in Postgres, sent over HTTPS only. The watch
  receives one at registration and never re-fetches.
- Coolify API token: stored at `~/.coolify-token` (chmod 600), never in
  the repo

## Observability

- All exceptions go through `app.onError` → `console.error`
- HTTP request logs via `hono/logger`
- Healthcheck at `/v1/health` includes a Postgres round-trip — if the DB
  is unreachable, returns 503 and Coolify will mark the container unhealthy
  and restart

## Reporting issues

If you find a security issue, email yogeshdahiya4@gmail.com. Do not file
a public GitHub issue.
