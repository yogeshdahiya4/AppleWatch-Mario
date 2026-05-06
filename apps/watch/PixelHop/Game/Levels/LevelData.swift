import Foundation
import CoreGraphics

/// Identifier for the four authored levels plus the aggregate "world1" submission.
enum LevelID: String, CaseIterable, Hashable, Codable {
    case world1_1 = "1-1"
    case world1_2 = "1-2"
    case world1_3 = "1-3"
    case world1_4 = "1-4"

    var displayName: String {
        switch self {
        case .world1_1: "Overworld"
        case .world1_2: "Underground"
        case .world1_3: "Sky"
        case .world1_4: "Castle"
        }
    }

    var next: LevelID? {
        switch self {
        case .world1_1: .world1_2
        case .world1_2: .world1_3
        case .world1_3: .world1_4
        case .world1_4: nil
        }
    }

    /// Soft per-level cap; matches backend SCORE_CAPS.
    var scoreCap: Int {
        switch self {
        case .world1_1: 50_000
        case .world1_2: 50_000
        case .world1_3: 60_000
        case .world1_4: 80_000
        }
    }
}

/// A tile is the fundamental unit of the world.
/// Encoded as a small integer so level layouts can be a `[String]` of single chars.
enum Tile: Character, Hashable {
    case empty       = "."
    case ground      = "G"
    case brick       = "B"
    case question    = "?"
    case hard        = "H"
    case pipeTopL    = "<"
    case pipeTopR    = ">"
    case pipeBodyL   = "["
    case pipeBodyR   = "]"
    case cloudL      = "{"
    case cloudM      = "-"
    case cloudR      = "}"
    case lava        = "L"
    case water       = "W"
    case castle      = "C"
    case flagPole    = "F"
    case flagTop     = "T"
    case checkpoint  = "K"
    case spikes      = "S"

    var isSolid: Bool {
        switch self {
        case .empty, .lava, .water, .spikes, .checkpoint, .flagPole, .flagTop:
            return false
        default:
            return true
        }
    }

    var isHazard: Bool {
        switch self {
        case .lava, .spikes:
            return true
        default:
            return false
        }
    }
}

/// A spawn point for an enemy or interactive entity.
struct EntitySpawn: Hashable {
    enum Kind: Hashable {
        case goomba
        case koopaGreen
        case koopaRed
        case piranha
        case lakitu
        case spiny
        case mushroom
        case fireFlower
        case coin
        case oneUp
        case bossBowserStomp
    }
    var kind: Kind
    /// Position in tile-grid coordinates.
    var tile: TilePoint
}

/// Tile-grid coordinate. Bottom-left of the level is (0,0).
struct TilePoint: Hashable {
    var x: Int
    var y: Int

    var cgPoint: CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

/// One playable level. The layout is column-major to match the side-scrolling
/// camera; row 0 is the *bottom* of the screen.
struct Level {
    let id: LevelID
    /// Column-major: tiles[col][row]. Width is tiles.count, height is constant.
    let tiles: [[Tile]]
    let height: Int
    let spawn: TilePoint
    let goal: TilePoint
    let entities: [EntitySpawn]
    /// Soundtrack identifier — picked by GameScene.
    let theme: Theme
    /// Total time allowed (seconds). 0 = no time limit.
    let timeLimit: Int

    enum Theme: String {
        case overworld
        case underground
        case sky
        case castle
    }

    var width: Int { tiles.count }

    func tile(at p: TilePoint) -> Tile {
        guard p.x >= 0, p.x < tiles.count, p.y >= 0, p.y < height else { return .empty }
        let col = tiles[p.x]
        guard p.y < col.count else { return .empty }
        return col[p.y]
    }
}

/// Result of a single play-through, used for HUD and leaderboard submission.
struct GameRunResult: Hashable, Codable {
    var level: LevelID
    var score: Int
    var coins: Int
    var timeMs: Int
    var died: Bool
    /// True only when the *aggregate* world1 run completed (all 4 levels in one session).
    var worldCompleted: Bool
}

/// Helper for parsing ASCII-art level layouts.
/// Strings are passed top-down (top of screen first). Each char = one tile.
/// Returns column-major tile grid + computed height.
enum LevelParser {
    static func parse(_ rows: [String]) -> (tiles: [[Tile]], height: Int) {
        let height = rows.count
        let width = rows.map(\.count).max() ?? 0
        var grid: [[Tile]] = Array(repeating: Array(repeating: .empty, count: height), count: width)
        for (rowIdx, line) in rows.enumerated() {
            // rowIdx 0 = top of screen. Convert to bottom-anchored Y.
            let y = height - 1 - rowIdx
            for (colIdx, ch) in line.enumerated() {
                if let t = Tile(rawValue: ch) {
                    grid[colIdx][y] = t
                }
            }
        }
        return (grid, height)
    }
}
