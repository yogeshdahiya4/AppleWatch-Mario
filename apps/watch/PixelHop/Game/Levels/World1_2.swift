import Foundation

/// World 1-2, the Underground. Tighter ceilings, lava pits, piranha plants.
/// Subverts what you learned in 1-1 by removing the open sky.
enum World1_2 {
    static func make() -> Level {
        let rows: [String] = [
            "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
            "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
            "................?...?......BBB.....BBB............................?B?B?B.................................BBBBBB............?...........................CCCCCCCCCCCCCCC",
            ".....................................................................................................................................................................",
            "...................?................................?B?...........................B..B..B...........BBBB..............?....?...........................................",
            ".....................................................................................................................................................................",
            ".......................................................................................................................................................T.............",
            "...........................................BB....................B..............................B...............BB...................................F..............",
            "...........................................BB....................B..............................B...............BB...................................F..............",
            "GG....GGG..GGG.....GGG.....GGGGG.....GGGG..GGG..GG......GGGGGG....GGGGG....GGGG....GGGGGG.....GGGGGGGGG..GGGG......GGG.GG..GGGGGG..GGGGGG.GGGG..GGGGG......G..GGGGGG.....GG",
            "GGLLLLGGGLLGGGLLLLLGGGLLLLLGGGGGLLLLLGGGGLLGGGLLGGGLLLLLLGGGGGGGLLLLGGGGGLLLLGGGGLLLLGGGGGGLLLLLGGGGGGGGGLLGGGGGLLLLLLGGGGGGLLGGGGGGLLGGGGGGLGGGGLLGGGGGLLLLLLGLLGGGGGGLLLLLGG",
            "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
        ]
        let parsed = LevelParser.parse(rows)
        let entities: [EntitySpawn] = [
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 22, y: 2)),
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 56, y: 2)),
            EntitySpawn(kind: .piranha, tile: TilePoint(x: 70, y: 3)),
            EntitySpawn(kind: .piranha, tile: TilePoint(x: 100, y: 3)),
            EntitySpawn(kind: .koopaGreen, tile: TilePoint(x: 122, y: 2)),
            EntitySpawn(kind: .coin, tile: TilePoint(x: 36, y: 5)),
            EntitySpawn(kind: .coin, tile: TilePoint(x: 37, y: 5)),
            EntitySpawn(kind: .coin, tile: TilePoint(x: 38, y: 5)),
            EntitySpawn(kind: .fireFlower, tile: TilePoint(x: 58, y: 5)),
            EntitySpawn(kind: .oneUp, tile: TilePoint(x: 80, y: 5)),
        ]
        return Level(
            id: .world1_2,
            tiles: parsed.tiles,
            height: parsed.height,
            spawn: TilePoint(x: 2, y: 2),
            goal: TilePoint(x: parsed.tiles.count - 12, y: 4),
            entities: entities,
            theme: .underground,
            timeLimit: 220
        )
    }
}
