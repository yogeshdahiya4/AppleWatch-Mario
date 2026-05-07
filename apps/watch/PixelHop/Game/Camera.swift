import CoreGraphics
import SpriteKit

/// Mario-style window-follow camera. The player roams freely inside a
/// horizontal "deadzone" centered on the camera; only when the player
/// crosses an edge does the camera scroll. Vertically, the camera tracks
/// the player gently with spring damping.
@MainActor
final class GameCamera {
    let node: SKCameraNode
    /// Horizontal half-width of the deadzone in pixels.
    var deadzoneHalfWidth: CGFloat = 14
    /// Vertical spring stiffness (0..1). 1 = instant follow.
    var verticalLerp: CGFloat = 0.18
    /// Bounds for the camera so it doesn't pan outside the level.
    var levelBounds: CGRect = .infinite

    init() {
        node = SKCameraNode()
    }

    /// Vertical look-ahead lerp factor (applied additively to target Y based
    /// on player velocity sign). 0 disables look-ahead.
    var verticalLookAhead: CGFloat = 12
    /// Last applied shake offset; subtracted before the next shake step so
    /// shakes don't compound with normal follow motion.
    private var shakeOffset: CGPoint = .zero

    func follow(_ target: CGPoint, viewportSize: CGSize, playerDy: CGFloat = 0) {
        // Undo last shake offset before computing fresh follow.
        node.position.x -= shakeOffset.x
        node.position.y -= shakeOffset.y
        shakeOffset = .zero

        // Horizontal window-follow with smoothing inside the deadzone.
        let dx = target.x - node.position.x
        if dx > deadzoneHalfWidth {
            node.position.x += (dx - deadzoneHalfWidth) * 0.35
        } else if dx < -deadzoneHalfWidth {
            node.position.x += (dx + deadzoneHalfWidth) * 0.35
        }

        // Vertical spring + look-ahead in the player's motion direction.
        let lookAhead: CGFloat = playerDy > 0 ? verticalLookAhead : (playerDy < 0 ? -verticalLookAhead : 0)
        let targetY = target.y + lookAhead
        let dy = targetY - node.position.y
        node.position.y += dy * verticalLerp

        // Clamp to level bounds (camera position is *center*).
        let visibleW = viewportSize.width * node.xScale
        let visibleH = viewportSize.height * node.yScale
        let halfW = visibleW / 2
        let halfH = visibleH / 2
        if levelBounds.size != .zero, levelBounds.width != .infinity {
            node.position.x = node.position.x.clamped(
                levelBounds.minX + halfW,
                max(levelBounds.minX + halfW, levelBounds.maxX - halfW)
            )
            node.position.y = node.position.y.clamped(
                levelBounds.minY + halfH,
                max(levelBounds.minY + halfH, levelBounds.maxY - halfH)
            )
        }
    }

    /// Quick screen shake. `magnitude` in points (≈4 is light, ≈10 is heavy).
    func shake(magnitude: CGFloat = 6, duration: TimeInterval = 0.18) {
        node.removeAction(forKey: "shake")
        let count = max(2, Int(duration / 0.04))
        var actions: [SKAction] = []
        var cumulative = CGPoint.zero
        for i in 0..<count {
            let damp = 1.0 - CGFloat(i) / CGFloat(count)
            let dx = CGFloat.random(in: -1...1) * magnitude * damp
            let dy = CGFloat.random(in: -1...1) * magnitude * damp
            actions.append(.move(by: CGVector(dx: dx - cumulative.x, dy: dy - cumulative.y), duration: 0.04))
            cumulative = CGPoint(x: dx, y: dy)
        }
        actions.append(.move(by: CGVector(dx: -cumulative.x, dy: -cumulative.y), duration: 0.04))
        node.run(.sequence(actions), withKey: "shake")
    }
}

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}
