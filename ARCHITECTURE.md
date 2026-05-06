# PixelHop architecture

## Module map

```
PixelHop (watchOS app)              services/api (Bun + Hono backend)
┌────────────────────────────┐       ┌────────────────────────────┐
│ App/                       │       │ src/                       │
│   PixelHopApp              │       │   index.ts (Hono app)      │
│ UI/                        │       │   routes/                  │
│   RootView, MainMenuView   │       │     devices.ts             │
│   GameContainerView   ─────┼─HTTP─▶│     scores.ts              │
│   LeaderboardView          │       │     leaderboard.ts         │
│   …                        │       │     health.ts              │
│ Game/                      │       │   middleware/              │
│   GameScene  ┐             │       │     hmac.ts                │
│   Player     │             │       │     rateLimit.ts           │
│   Physics    │ tile-grid   │       │   db/                      │
│   Camera     │ AABB        │       │     schema.ts (Drizzle)    │
│   Enemy      │             │       │     client.ts              │
│   Levels/    ┘             │       │     migrations/            │
│ Input/                     │       └────────────────────────────┘
│   InputController          │                   │
│ Networking/                │                   ▼
│   APIClient                │            ┌─────────────┐
│   HMACSigner               │            │ Postgres 16 │
│   ScoreSubmitter (offline) │            │  (Coolify)  │
│ Persistence/               │            └─────────────┘
│   DeviceIdentity (Keychain)│
│   GameSave (UserDefaults)  │
│ Audio/                     │
│   Haptics, Sound           │
└────────────────────────────┘
```

## Per-frame flow (60 fps target)

```
WatchOS DragGesture / DigitalCrown
        │
        ▼
InputController
  • horizontal drag → moveAxis ∈ [-1, 1]
  • upward velocity buffer → flick-jump detection
  • crown rotation → discrete events
        │
        ▼
GameScene.update(dt)
  • Player.tick(moveAxis, jumpHeld, jumpFlicked, level)
      ─ horizontal accel + friction
      ─ gravity, sweepX(level), sweepY(level)
      ─ coyote-time / jump-buffer state machine
      ─ hazard-overlap check
  • for each enemy: tick + AABB intersect with player
  • coin overlap → +score, haptic, remove
  • goal overlap → finishLevel(succeeded: true)
  • Camera.follow(playerCenter)
        │
        ▼
@Published HUDState  →  SwiftUI HUDView
PassthroughSubject     →  GameContainerView level-end handler
                            ↓
                 handleLevelEnd(GameRunResult)
                            ↓
                  ┌─────────┴─────────┐
                  ▼                   ▼
           Persistence/         Networking/
           GameSave.record      ScoreSubmitter.submit
                                       │
                                  ┌────┴─────┐
                                  ▼          ▼
                              online?    queue locally
                                  │       (pendingScores.json)
                                  ▼
                         POST /v1/scores  (HMAC-signed)
```

## HMAC signing protocol (watch ↔ backend)

Both sides must produce/verify the **exact same** message. Format:

```
message = METHOD \n PATH \n TIMESTAMP \n NONCE \n BODY
sig     = hex(HMAC-SHA256(per-device-secret, message))
```

Headers on every signed request:
- `X-Device-Id`     (uuid, lowercase)
- `X-Timestamp`     (unix epoch seconds; ±300s window)
- `X-Nonce`         (≥16 hex chars; backend rejects re-use within TTL)
- `X-Sig`           (hex of HMAC-SHA256)

Backend behaviors:
- Constant-time signature compare (prevents timing attacks)
- Insert nonce into `nonces` table; PK violation = replay → 401
- ±5-min timestamp window
- Score validity: per-level cap + minimum-time floor
- Token-bucket rate limit per device id

## Tile-grid AABB (why not SKPhysicsBody)

We use a **custom integer-tile sweep** for the player and enemies because
SpriteKit's physics engine optimizes for general 2D rigid bodies, not for
the specific feel of a Mario-style platformer:

| Concern                        | SKPhysicsBody          | Custom AABB sweep    |
|---                             |---                     |---                   |
| Coyote time (jump after lege)  | Hard to tune           | Counter in Player    |
| Jump buffer (early-press grace)| Manual integration     | Counter in Player    |
| Pixel-perfect ground detect    | Approximate            | Exact tile lookup    |
| Variable jump height           | Apply force per-frame  | Boost per-frame      |
| Corner correction              | Solver-dependent       | Sweep + binary search|

Sweep algorithm:
1. Compute target AABB if we apply full delta
2. If no overlap with solid tiles → take full delta (fast path)
3. Otherwise binary-search [0, delta] over 8 iterations for the largest
   non-overlapping fraction → ~0.39% precision in 8 steps

This is faster and more deterministic than SKPhysicsWorld and gives the
exact platformer feel we want.

## Single-finger control model

Every input must reachable from one finger while wearing the watch:

```
                ┌──────────────────┐  top half: tap dead-zone
                │                  │  (joystick UI rendered here too)
                │                  │
                │       game       │
                │                  │
                │                  │
                ├──────────────────┤  bottom 40%: joystick zone
                │  ╭──────────╮    │
                │  │  ●  ─── ─┼──── │  finger lands → drag horizontally to move
                │  ╰──────────╯    │  flick upward → jump (variable height)
                └──────────────────┘
```

Detection in `InputController`:
- Drag captures `touchDown` → starts a `DragState` with origin
- `touchMoved` updates a 4-frame ring buffer of vertical deltas
- When average upward velocity ≥ flickThreshold AND total upward
  displacement ≥ flickMinDisplacement → fire jump event with magnitude
- `touchUp` with overall upward swing also fires jump (lift-flick)
- Crown rotation accumulates 30° before firing a discrete event —
  that becomes the only input the crown drives in-game

## Why these stack choices

| Layer                | Choice                       | Why                              |
|---                   |---                           |---                               |
| Watch UI shell       | SwiftUI                       | Native; SpriteView bridge to SK   |
| Game rendering       | SpriteKit (SpriteView)        | Hardware-accelerated 2D batches   |
| Game physics         | Custom AABB                   | See above — platformer feel       |
| Persistent identity  | Keychain (per-device UUID)    | Survives app reinstall, device-only |
| Save game            | UserDefaults JSON             | <1KB, no SwiftData overhead       |
| Sound                | AVAudioPlayer per clip        | 6 SFX, low memory cost            |
| Network              | URLSession async/await        | Standard, retries, backoff        |
| Backend runtime      | Bun                           | ~3x cold-start vs Node            |
| Web framework        | Hono                          | Smallest, fastest router for Bun  |
| ORM                  | Drizzle                       | Type-safe, migrations from schema |
| Database             | Postgres 16                   | citext, partial indexes for hot path |
| Hosting              | Coolify on the user's VPS     | Self-hosted, simple, cheap        |

## Performance budget (60fps target on Series 10)

- < 16.6ms / frame
  - ~2ms input + state machine
  - ~3ms physics sweeps (small worlds, low entity counts)
  - ~8ms SpriteKit render
  - ~3ms slack for GC / Combine emission
- < 100MB RAM (watchOS extension limit)
- App size target < 50MB (placeholder squares; sprite atlas later)

## Known limitations / v1.1 backlog

- Boss AI in 1-4 is a placeholder sprite — stomp-on-axe works but no patrol
- Piranha plants and Lakitu have static placeholder sprites; no behavior
- No music tracks (only SFX); a small chiptune loop per theme is on the list
- Always-On Display: full implementation pending — currently the game pauses
- iCloud sync of save data: not in v1
