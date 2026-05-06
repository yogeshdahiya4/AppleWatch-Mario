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

    func follow(_ target: CGPoint, viewportSize: CGSize) {
        // Horizontal window-follow
        let dx = target.x - node.position.x
        if dx > deadzoneHalfWidth {
            node.position.x += dx - deadzoneHalfWidth
        } else if dx < -deadzoneHalfWidth {
            node.position.x += dx + deadzoneHalfWidth
        }

        // Vertical spring
        let dy = target.y - node.position.y
        node.position.y += dy * verticalLerp

        // Clamp to level bounds (camera position is *center*)
        let halfW = viewportSize.width / 2
        let halfH = viewportSize.height / 2
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
}

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}
