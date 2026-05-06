import Foundation

/// World 1-4, the Castle. Stone palette, lava floors, narrow corridors,
/// and a stomp-on-axe boss. Bowser-equivalent ("Brokork") paces a bridge —
/// land on the axe at the far end to drop the bridge and win.
enum World1_4 {
    static func make() -> Level {
        let rows: [String] = [
            "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
            "H........H...........H...........H..............H............H...............H.......................H.......................................H",
            "H........H...........H...........H..............H............H...............H.......................H.......................................H",
            "H........H...........H...........H..............H............H...............H.......................H...........................T...........H",
            "H........H...........H...........H..............H............H...............H.......................H...........................F...........H",
            "H........HHHHHHH.....H.....HHHHHHH.....HHHHHHHHH.HHHHHH.......HHHHHH..........HHHHH...HHHHHHHHHHHH.....H...........................F...........H",
            "H..........................................................................................................................................F...........H",
            "H........................................................?..............................................................................F............H",
            "H...........................?B?...?..........BB.................?BBB?....?.B.............................................CCCCCCCCCCCCCCCCCCC",
            "H........H..........HHHH.........H...HHHHHHHH..HHHHHHH......H........HHHHHHHHHHHHHHH..H..H...HH...........H.....HHH......HHHHHHHHHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
            "HLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLH",
            "HLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLH",
            "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
        ]
        let parsed = LevelParser.parse(rows)
        let entities: [EntitySpawn] = [
            EntitySpawn(kind: .goomba, tile: TilePoint(x: 18, y: 5)),
            EntitySpawn(kind: .koopaRed, tile: TilePoint(x: 42, y: 5)),
            EntitySpawn(kind: .piranha, tile: TilePoint(x: 60, y: 5)),
            EntitySpawn(kind: .koopaRed, tile: TilePoint(x: 82, y: 8)),
            EntitySpawn(kind: .fireFlower, tile: TilePoint(x: 30, y: 6)),
            EntitySpawn(kind: .bossBowserStomp, tile: TilePoint(x: 110, y: 5)),
        ]
        return Level(
            id: .world1_4,
            tiles: parsed.tiles,
            height: parsed.height,
            spawn: TilePoint(x: 2, y: 5),
            goal: TilePoint(x: parsed.tiles.count - 18, y: 5),
            entities: entities,
            theme: .castle,
            timeLimit: 260
        )
    }
}

enum LevelLoader {
    static func load(_ id: LevelID) -> Level {
        switch id {
        case .world1_1: World1_1.make()
        case .world1_2: World1_2.make()
        case .world1_3: World1_3.make()
        case .world1_4: World1_4.make()
        }
    }
}
