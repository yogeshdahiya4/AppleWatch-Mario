import CoreGraphics
import Foundation

/// Tile-grid AABB physics. Custom-built (not SKPhysicsBody) because
/// platformer feel — coyote time, jump buffering, pixel-tight ground
/// detection, and corner correction — requires per-frame control of
/// resolution order that SpriteKit's physics doesn't expose.
///
/// Coordinates are in *world pixels*, with Y increasing upward.
/// One tile = `Constants.tileSize` pixels.
enum Constants {
    /// Side of one square tile, in points (rendered).
    static let tileSize: CGFloat = 16

    /// Player AABB size in pixels.
    static let playerSize = CGSize(width: 12, height: 14)

    /// Gravity per frame at 60fps (px / frame²).
    static let gravity: CGFloat = 0.55

    /// Cap on downward velocity so we never tunnel through tiles.
    static let maxFallSpeed: CGFloat = 9.5

    /// Initial upward jump impulse (px / frame).
    static let jumpImpulse: CGFloat = -8.6

    /// Extra upward force while jump is "held" (variable height).
    static let jumpHoldBoost: CGFloat = -0.35

    /// Max number of frames the jump-hold boost is applied.
    static let maxJumpHoldFrames: Int = 12

    /// Lateral acceleration from input (px / frame²).
    static let runAccel: CGFloat = 0.35

    /// Max horizontal speed (px / frame).
    static let maxRunSpeed: CGFloat = 3.6

    /// Friction applied when there's no input (multiplier per frame).
    static let friction: CGFloat = 0.84

    /// Air control multiplier.
    static let airControl: CGFloat = 0.6

    /// Frames the player can still jump after walking off a ledge.
    static let coyoteFrames: Int = 6

    /// Frames a queued jump-press stays valid waiting for the player to land.
    static let jumpBufferFrames: Int = 5
}

/// Axis-aligned bounding box in world coordinates.
struct AABB {
    var origin: CGPoint   // bottom-left
    var size: CGSize

    var minX: CGFloat { origin.x }
    var maxX: CGFloat { origin.x + size.width }
    var minY: CGFloat { origin.y }
    var maxY: CGFloat { origin.y + size.height }

    func intersects(_ other: AABB) -> Bool {
        !(maxX <= other.minX || minX >= other.maxX || maxY <= other.minY || minY >= other.maxY)
    }
}

/// Result of applying a single-axis sweep against the tile grid.
struct SweepResult {
    var resolvedDelta: CGFloat
    var hitWall: Bool
}

/// Checks whether any solid tile overlaps the supplied AABB in the given level.
func anySolidOverlap(box: AABB, level: Level) -> Bool {
    let ts = Constants.tileSize
    let minTx = Int(floor(box.minX / ts))
    let maxTx = Int(floor((box.maxX - 0.001) / ts))
    let minTy = Int(floor(box.minY / ts))
    let maxTy = Int(floor((box.maxY - 0.001) / ts))

    for tx in minTx...maxTx {
        for ty in minTy...maxTy {
            let t = level.tile(at: TilePoint(x: tx, y: ty))
            if t.isSolid { return true }
        }
    }
    return false
}

/// Returns true if any hazard tile overlaps the AABB.
func anyHazardOverlap(box: AABB, level: Level) -> Bool {
    let ts = Constants.tileSize
    let minTx = Int(floor(box.minX / ts))
    let maxTx = Int(floor((box.maxX - 0.001) / ts))
    let minTy = Int(floor(box.minY / ts))
    let maxTy = Int(floor((box.maxY - 0.001) / ts))

    for tx in minTx...maxTx {
        for ty in minTy...maxTy {
            if level.tile(at: TilePoint(x: tx, y: ty)).isHazard { return true }
        }
    }
    return false
}

/// Sweeps the box by `dx` along the X axis, stopping at the first solid tile.
func sweepX(box: AABB, dx: CGFloat, level: Level) -> SweepResult {
    if dx == 0 { return SweepResult(resolvedDelta: 0, hitWall: false) }
    let target = AABB(origin: CGPoint(x: box.origin.x + dx, y: box.origin.y), size: box.size)
    if !anySolidOverlap(box: target, level: level) {
        return SweepResult(resolvedDelta: dx, hitWall: false)
    }
    var lo: CGFloat = 0
    var hi: CGFloat = dx
    for _ in 0..<8 {
        let mid = (lo + hi) / 2
        let probe = AABB(origin: CGPoint(x: box.origin.x + mid, y: box.origin.y), size: box.size)
        if anySolidOverlap(box: probe, level: level) {
            hi = mid
        } else {
            lo = mid
        }
    }
    return SweepResult(resolvedDelta: lo, hitWall: true)
}

/// Sweeps the box by `dy` along the Y axis. Negative dy = falling down.
func sweepY(box: AABB, dy: CGFloat, level: Level) -> SweepResult {
    if dy == 0 { return SweepResult(resolvedDelta: 0, hitWall: false) }
    let target = AABB(origin: CGPoint(x: box.origin.x, y: box.origin.y + dy), size: box.size)
    if !anySolidOverlap(box: target, level: level) {
        return SweepResult(resolvedDelta: dy, hitWall: false)
    }
    var lo: CGFloat = 0
    var hi: CGFloat = dy
    for _ in 0..<8 {
        let mid = (lo + hi) / 2
        let probe = AABB(origin: CGPoint(x: box.origin.x, y: box.origin.y + mid), size: box.size)
        if anySolidOverlap(box: probe, level: level) {
            hi = mid
        } else {
            lo = mid
        }
    }
    return SweepResult(resolvedDelta: lo, hitWall: true)
}

/// Whether the box has a solid tile directly below (within 1 px).
func isOnGround(box: AABB, level: Level) -> Bool {
    let probe = AABB(
        origin: CGPoint(x: box.origin.x, y: box.origin.y - 1),
        size: box.size
    )
    return anySolidOverlap(box: probe, level: level)
}
