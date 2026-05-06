# Contributing to PixelHop

## Adding a new level

Levels live as **compile-checked Swift code**, not JSON files, so a typo
becomes a build error rather than a silent runtime failure. Each level
is a function returning a `Level` value built from an ASCII grid +
explicit entity spawn list.

### 1. Create the level file

`apps/watch/PixelHop/Game/Levels/World2_1.swift`:

```swift
import Foundation

enum World2_1 {
    static func make() -> Level {
        let rows: [String] = [
            "...........{-}.................T....",
            "...........................F.........",
            // … your tile grid, top-down
            "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
        ]
        let parsed = LevelParser.parse(rows)
        let entities: [EntitySpawn] = [
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 12, y: 2)),
            // …
        ]
        return Level(
            id: .world2_1,
            tiles: parsed.tiles,
            height: parsed.height,
            spawn: TilePoint(x: 2, y: 2),
            goal: TilePoint(x: parsed.tiles.count - 8, y: 4),
            entities: entities,
            theme: .overworld,
            timeLimit: 220
        )
    }
}
```

### 2. Add the new ID + loader case

In `LevelData.swift`:

```swift
enum LevelID: String, CaseIterable, Hashable, Codable {
    // …
    case world2_1 = "2-1"
}
```

In `World1_4.swift` (or extract `LevelLoader` into its own file):

```swift
enum LevelLoader {
    static func load(_ id: LevelID) -> Level {
        switch id {
        // …
        case .world2_1: World2_1.make()
        }
    }
}
```

### 3. Tile alphabet

| Char | Tile | Solid? | Hazard? | Notes |
|---|---|---|---|---|
| `.` | empty | no | no | sky / air |
| `G` | ground | yes | — | overworld dirt or castle stone (per theme) |
| `B` | brick | yes | — | breakable from below (visual; in v1 they're solid) |
| `?` | question | yes | — | mystery block |
| `H` | hard | yes | — | unbreakable hard block |
| `<` `>` | pipe top L/R | yes | — | render as one logical pipe |
| `[` `]` | pipe body L/R | yes | — | extends downward |
| `{` `-` `}` | cloud L/M/R | yes | — | sky platform — semi-solid |
| `L` | lava | no | yes | instant death |
| `S` | spikes | no | yes | instant death |
| `W` | water | no | — | swim physics not implemented in v1 |
| `C` | castle | yes | — | end-of-castle decorative block |
| `F` | flag pole | no | — | level goal — touch to clear |
| `T` | flag top | no | — | renders the flag on top of the pole |
| `K` | checkpoint | no | — | mid-level respawn (v1.1) |

### 4. Entity spawn kinds

```
.goomba          basic stompable enemy
.koopaGreen      shell-on-stomp, walks off ledges
.koopaRed        shell-on-stomp, doesn't walk off ledges
.piranha         placeholder sprite (full AI in v1.1)
.lakitu          placeholder
.spiny           placeholder
.coin            +200 score, +1 coin, +haptic
.mushroom        small → big size up, +1000
.fireFlower      gives ranged attack mode (v1.1)
.oneUp           +1 life
.bossBowserStomp end-of-castle stomp-on-axe trigger
```

### 5. Test

```bash
cd apps/watch
xcodegen generate
xcodebuild -project PixelHop.xcodeproj -scheme "PixelHop Watch App" \
  -sdk watchsimulator26.4 build
# Then run from Xcode on a Series 10 simulator
```

If you don't have the simulator runtime installed, the headless typecheck
catches most errors:

```bash
SDK=/Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk
find apps/watch/PixelHop -name "*.swift" -print0 | \
  xargs -0 /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc \
    -sdk "$SDK" -target arm64-apple-watchos11.0 -typecheck
```

### 6. Update the leaderboard schema

If the new level id needs a leaderboard, add it to:

- `services/api/src/routes/scores.ts` → `LEVELS` array, `SCORE_CAPS`, `TIME_FLOORS`
- `services/api/src/routes/leaderboard.ts` → the `LEVELS` Set
- Re-run `tools/test-api.sh` to confirm

## Adding a new enemy

1. Conform to `Enemy` in `Game/Enemy.swift`
2. Render via `SKSpriteNode` for now (sprite-atlas pipeline in `Game/Levels/LevelData.swift` Phase 5)
3. In `GameScene.swift`, add a case to `spawnEntities` for the new `EntitySpawn.Kind`

## Style

- Default to writing **no comments**. Only when the *why* is non-obvious — a
  hidden constraint, a counter-intuitive optimization. Code should
  self-document via clear names.
- Backend env vars: never commit secrets. Local `.env` is gitignored;
  Coolify env vars set via API in `tools/coolify-bootstrap.sh`.
- Match Apple platform availability: every API used must be marked as
  `available` on watchOS or the typecheck fails. Don't reach for `UIColor.systemX`
  (iOS-only) — use `SKColor(red:green:blue:alpha:)` literals instead.
