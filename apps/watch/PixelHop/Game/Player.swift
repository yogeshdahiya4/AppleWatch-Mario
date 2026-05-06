import CoreGraphics
import Foundation
import SpriteKit

/// The player character. State machine + physics intent. Owns its sprite.
@MainActor
final class Player {
    enum Mode {
        case small
        case big        // mushroom power-up
        case fire       // fire flower
    }

    enum Animation: String {
        case idle, run, jump, hurt, dead
    }

    // MARK: - State
    var box: AABB
    var velocity: CGVector = .zero
    var facingRight: Bool = true
    var mode: Mode = .small
    var alive: Bool = true
    var invincibleFramesLeft: Int = 0   // post-hit i-frames

    // Jump state
    private var groundedFramesAgo: Int = 999       // for coyote time
    private var bufferedJumpFramesLeft: Int = 0    // for jump buffering
    private var jumpHoldFramesUsed: Int = 0
    private var inAir: Bool = false

    // MARK: - Visual
    let node: SKNode
    private let sprite: SKSpriteNode
    private var currentAnim: Animation = .idle

    init(spawn: CGPoint, atlas: SKTextureAtlas?) {
        self.box = AABB(
            origin: CGPoint(x: spawn.x, y: spawn.y),
            size: Constants.playerSize
        )
        self.node = SKNode()
        self.sprite = SKSpriteNode(color: SKColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1), size: Constants.playerSize)
        node.addChild(sprite)
        node.position = CGPoint(x: spawn.x + Constants.playerSize.width / 2,
                                 y: spawn.y + Constants.playerSize.height / 2)
        if let atlas {
            applyAtlas(atlas)
        }
    }

    private func applyAtlas(_ atlas: SKTextureAtlas) {
        // Try to grab idle/run/jump frames from the atlas; fall back to flat color.
        if let idle = atlas.textureNames.first(where: { $0.contains("idle") }) {
            sprite.texture = atlas.textureNamed(idle)
            sprite.size = Constants.playerSize
            sprite.color = .clear
            sprite.colorBlendFactor = 0
        }
    }

    // MARK: - Per-frame update

    /// Run one physics + animation tick.
    /// `moveAxis`: -1..1 from joystick. `jumpHeld`: held-since-last-flick.
    /// `level`: the current level for collision.
    /// Returns the world-space center the camera should look at.
    func tick(moveAxis: CGFloat, jumpHeld: Bool, jumpFlicked: Bool, level: Level) -> CGPoint {
        guard alive else {
            // Death animation: fall off screen, no input.
            velocity.dy = max(velocity.dy + Constants.gravity, -Constants.maxFallSpeed)
            box.origin.y += velocity.dy
            updateNodePosition()
            return centerWorld
        }

        // Horizontal: accelerate toward target axis with air-control attenuation
        let onGround = isOnGround(box: box, level: level)
        let accelMul: CGFloat = onGround ? 1.0 : Constants.airControl
        if moveAxis != 0 {
            velocity.dx += moveAxis * Constants.runAccel * accelMul
            velocity.dx = velocity.dx.clamped(-Constants.maxRunSpeed, Constants.maxRunSpeed)
            facingRight = moveAxis > 0
        } else if onGround {
            velocity.dx *= Constants.friction
            if abs(velocity.dx) < 0.05 { velocity.dx = 0 }
        }

        // Coyote time tracking
        if onGround {
            groundedFramesAgo = 0
            inAir = false
            jumpHoldFramesUsed = 0
        } else {
            groundedFramesAgo += 1
        }

        // Jump buffering
        if jumpFlicked {
            bufferedJumpFramesLeft = Constants.jumpBufferFrames
        }
        if bufferedJumpFramesLeft > 0 { bufferedJumpFramesLeft -= 1 }

        let canJump = groundedFramesAgo <= Constants.coyoteFrames
        if canJump, bufferedJumpFramesLeft > 0 {
            velocity.dy = Constants.jumpImpulse
            inAir = true
            groundedFramesAgo = Constants.coyoteFrames + 1
            bufferedJumpFramesLeft = 0
        }

        // Variable jump height while held
        if inAir, jumpHeld, velocity.dy < 0, jumpHoldFramesUsed < Constants.maxJumpHoldFrames {
            velocity.dy += Constants.jumpHoldBoost
            jumpHoldFramesUsed += 1
        }

        // Gravity
        velocity.dy = (velocity.dy + Constants.gravity).clamped(-99, Constants.maxFallSpeed)

        // Resolve X
        let xRes = sweepX(box: box, dx: velocity.dx, level: level)
        box.origin.x += xRes.resolvedDelta
        if xRes.hitWall { velocity.dx = 0 }

        // Resolve Y
        let yRes = sweepY(box: box, dy: velocity.dy, level: level)
        box.origin.y += yRes.resolvedDelta
        if yRes.hitWall {
            // ceiling or floor — clear vertical velocity
            if velocity.dy > 0 { velocity.dy = 0; jumpHoldFramesUsed = Constants.maxJumpHoldFrames }
            else { velocity.dy = 0 }
        }

        // Hazard check (lava, spikes)
        if anyHazardOverlap(box: box, level: level) {
            takeDamage(fatal: true)
        }

        if invincibleFramesLeft > 0 { invincibleFramesLeft -= 1 }
        updateAnimation(onGround: onGround, moving: moveAxis != 0)
        updateNodePosition()
        return centerWorld
    }

    func takeDamage(fatal: Bool) {
        guard alive else { return }
        if invincibleFramesLeft > 0 { return }
        if fatal || mode == .small {
            alive = false
            velocity.dy = -10
            currentAnim = .dead
        } else {
            mode = .small
            invincibleFramesLeft = 90
            currentAnim = .hurt
        }
    }

    private var centerWorld: CGPoint {
        CGPoint(
            x: box.origin.x + box.size.width / 2,
            y: box.origin.y + box.size.height / 2
        )
    }

    private func updateNodePosition() {
        node.position = centerWorld
        sprite.xScale = facingRight ? 1 : -1
        if invincibleFramesLeft > 0 {
            sprite.alpha = (invincibleFramesLeft / 4).isMultiple(of: 2) ? 0.4 : 1.0
        } else {
            sprite.alpha = 1.0
        }
    }

    private func updateAnimation(onGround: Bool, moving: Bool) {
        let next: Animation
        if !alive { next = .dead }
        else if !onGround { next = .jump }
        else if moving { next = .run }
        else { next = .idle }
        if next != currentAnim {
            currentAnim = next
            // Animation playback driven by sprite atlas in Phase 5; placeholder no-op.
        }
    }
}

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}
