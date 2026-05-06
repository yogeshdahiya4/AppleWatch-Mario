import Foundation
import WatchKit

/// Tiny wrapper around WKHapticType with rate-limiting to avoid spam.
@MainActor
enum Haptics {
    private static var lastFired: [WKHapticType: TimeInterval] = [:]

    static func play(_ type: WKHapticType, minInterval: TimeInterval = 0.06) {
        let now = Date().timeIntervalSinceReferenceDate
        if let last = lastFired[type], now - last < minInterval { return }
        lastFired[type] = now
        WKInterfaceDevice.current().play(type)
    }

    static func jump() { play(.click, minInterval: 0.05) }
    static func coin() { play(.success, minInterval: 0.18) }   // throttle, lots of coins
    static func stomp() { play(.directionUp, minInterval: 0.05) }
    static func hurt() { play(.failure, minInterval: 0.4) }
    static func levelClear() { play(.notification, minInterval: 1.0) }
    static func powerUp() { play(.start, minInterval: 0.5) }
}

