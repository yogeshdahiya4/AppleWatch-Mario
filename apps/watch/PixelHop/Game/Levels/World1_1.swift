import Foundation

/// World 1-1, the Overworld. Your classic introductory side-scroller —
/// learn to run, jump, stomp, and spend a coin or two. ~ 200 tiles wide.
enum World1_1 {
    static func make() -> Level {
        // 14 rows tall; rows are top-down (sky → ground).
        // Tile chars come from `Tile`'s rawValue.
        // legend: . empty   G ground   B brick   ? question   H hard   < > pipe-top   [ ] pipe-body
        //         { - } cloud   F flag-pole   T flag-top     K checkpoint
        //         numbers below are column rulers, every 10 chars.
        let rows: [String] = [
            // 0         1         2         3         4         5         6         7         8         9         10        11        12        13        14        15        16        17        18        19
            // 0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
            "....................{-}.....................................{-}........{-}.................................{-}.....................................................T.................",
            ".....................................................................................................................................................................F.................",
            "....................................................................................................................................................................F.................",
            ".......................................................?.B?B........................?...B.B..............?B?...B.B................................................F....................",
            ".....................................................................................................................................................................F.................",
            "..................................?...........B?B................................B..........B...........K..............................B................B...B.....F....................",
            ".....................................................................................................................................................................F.................",
            ".....................................................<>....................<>...................<>........................................<>........<>.................................",
            ".....................................................[]....................[]...................[]........................................[]........[]....C......C....................",
            "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG[]GGGGGG......GGGGGGGG[]GGGGGGGGGGGGGGGGGGG[]GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG[]GGGGGGGGGGG[]GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
            "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG......GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
        ]
        let parsed = LevelParser.parse(rows)
        let entities: [EntitySpawn] = [
            // Goombas spread out at increasing difficulty
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 24, y: 2)),
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 38, y: 2)),
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 78, y: 2)),
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 110, y: 2)),
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 138, y: 2)),
            // One green Koopa near the second pipe
            EntitySpawn(kind: .koopaGreen, tile: TilePoint(x: 86, y: 2)),
            // One coin floating over the gap
            EntitySpawn(kind: .coin, tile: TilePoint(x: 60, y: 4)),
            EntitySpawn(kind: .coin, tile: TilePoint(x: 61, y: 4)),
            EntitySpawn(kind: .coin, tile: TilePoint(x: 62, y: 4)),
            // Power-up in one of the ?-blocks (col ~28)
            EntitySpawn(kind: .mushroom, tile: TilePoint(x: 28, y: 4)),
        ]
        return Level(
            id: .world1_1,
            tiles: parsed.tiles,
            height: parsed.height,
            spawn: TilePoint(x: 2, y: 2),
            goal: TilePoint(x: parsed.tiles.count - 13, y: 4),
            entities: entities,
            theme: .overworld,
            timeLimit: 240
        )
    }
}
