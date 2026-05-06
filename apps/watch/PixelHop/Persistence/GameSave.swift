import Foundation

/// Per-device persistent progress. Kept tiny — UserDefaults is fine, no need
/// for SwiftData for ~100 bytes.
struct GameSave: Codable, Equatable {
    var bestPerLevel: [String: Int]    // levelID.rawValue -> best score
    var bestTimePerLevel: [String: Int] // levelID.rawValue -> best time_ms (lower = better)
    var bestWorldScore: Int
    var bestWorldTime: Int             // ms
    var coinsCollected: Int
    var farthestLevel: String          // last level reached

    static let empty = GameSave(
        bestPerLevel: [:],
        bestTimePerLevel: [:],
        bestWorldScore: 0,
        bestWorldTime: 0,
        coinsCollected: 0,
        farthestLevel: LevelID.world1_1.rawValue
    )

    private static let key = "pixelhop.save.v1"

    static func load() -> GameSave {
        guard let data = UserDefaults.standard.data(forKey: key) else { return .empty }
        return (try? JSONDecoder().decode(GameSave.self, from: data)) ?? .empty
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    /// Record a level result and persist. Returns true if it was a new best.
    @discardableResult
    mutating func record(_ result: GameRunResult) -> Bool {
        var newBest = false
        let key = result.level.rawValue
        let prev = bestPerLevel[key] ?? 0
        if result.score > prev {
            bestPerLevel[key] = result.score
            newBest = true
        }
        let prevTime = bestTimePerLevel[key] ?? .max
        if result.timeMs < prevTime, !result.died {
            bestTimePerLevel[key] = result.timeMs
        }
        if result.worldCompleted {
            if result.score > bestWorldScore {
                bestWorldScore = result.score
                newBest = true
            }
            if result.timeMs < bestWorldTime || bestWorldTime == 0 {
                bestWorldTime = result.timeMs
            }
        }
        coinsCollected += result.coins
        // Track farthest reached level
        if let next = result.level.next, !result.died {
            farthestLevel = next.rawValue
        }
        persist()
        return newBest
    }
}
