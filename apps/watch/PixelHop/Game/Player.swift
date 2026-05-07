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
        case idle, run, jump, fall, hurt, dead
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
        let registry = SpriteRegistry.shared
        // Render a slightly oversized sprite so the 24-pt character pops out of
        // the 18×22 collision box.
        let renderSize = CGSize(width: Constants.playerSize.width * 1.4,
                                  height: Constants.playerSize.height * 1.4)
        if let tex = registry.playerTexture(state: "idle") {
            self.sprite = SKSpriteNode(texture: tex, size: renderSize)
        } else {
            self.sprite = SKSpriteNode(color: SKColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1), size: renderSize)
        }
        sprite.zPosition = 1
        node.addChild(sprite)
        node.position = CGPoint(x: spawn.x + Constants.playerSize.width / 2,
                                 y: spawn.y + Constants.playerSize.height / 2)
        // Soft white halo behind the sprite so it pops against any backdrop.
        let halo = SKShapeNode(circleOfRadius: max(Constants.playerSize.width, Constants.playerSize.height) * 0.7)
        halo.fillColor = .white
        halo.strokeColor = .clear
        halo.alpha = 0.18
        halo.zPosition = -1
        node.addChild(halo)
        // Kick off the idle animation cycle.
        playAnimation(.idle)
    }

    // MARK: - Animation cycles

    private func framesAction(_ state: Animation) -> SKAction {
        let frames = SpriteRegistry.shared.playerFrames(state: state.rawValue)
        guard frames.count > 1 else {
            // Single frame — just set the texture, no animation.
            return SKAction.run { [weak self] in
                if let f = frames.first { self?.sprite.texture = f }
            }
        }
        let timePerFrame: TimeInterval = (state == .run) ? 0.10 : 0.18
        let anim = SKAction.animate(with: frames, timePerFrame: timePerFrame, resize: false, restore: true)
        return .repeatForever(anim)
    }

    private func playAnimation(_ state: Animation) {
        sprite.removeAction(forKey: "anim")
        sprite.run(framesAction(state), withKey: "anim")
    }

    // Squash on takeoff, stretch on landing — gives jumps a sense of weight.
    func playJumpSquash() {
        sprite.removeAction(forKey: "squash")
        let down = SKAction.scale(to: CGSize(width: sprite.size.width * 1.10, height: sprite.size.height * 0.85), duration: 0.05)
        let up = SKAction.scale(to: sprite.size, duration: 0.10)
        sprite.run(.sequence([down, up]), withKey: "squash")
    }

    func playLandSquash() {
        sprite.removeAction(forKey: "squash")
        let down = SKAction.scale(to: CGSize(width: sprite.size.width * 1.15, height: sprite.size.height * 0.78), duration: 0.06)
        let up = SKAction.scale(to: sprite.size, duration: 0.10)
        sprite.run(.sequence([down, up]), withKey: "squash")
    }

    // MARK: - Per-frame update

    /// Run one physics + animation tick.
    /// `moveAxis`: -1..1 from joystick. `jumpHeld`: held-since-last-flick.
    /// `level`: the current level for collision.
    /// Returns the world-space center the camera should look at.
    func tick(moveAxis: CGFloat, jumpHeld: Bool, jumpFlicked: Bool, level: Level) -> CGPoint {
        guard alive else {
            // Death animation: fall off screen, no input.
            // y-up: "down" = subtract gravity from dy; clamp downward speed.
            velocity.dy = max(velocity.dy - Constants.gravity, -Constants.maxFallSpeed)
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

        // Variable jump height while held — extend upward motion only while ascending.
        if inAir, jumpHeld, velocity.dy > 0, jumpHoldFramesUsed < Constants.maxJumpHoldFrames {
            velocity.dy += Constants.jumpHoldBoost
            jumpHoldFramesUsed += 1
        }

        // Gravity — y-up: subtract per frame, clamp downward speed (negative).
        velocity.dy = (velocity.dy - Constants.gravity).clamped(-Constants.maxFallSpeed, 99)

        // Resolve X
        let xRes = sweepX(box: box, dx: velocity.dx, level: level)
        box.origin.x += xRes.resolvedDelta
        if xRes.hitWall { velocity.dx = 0 }

        // Resolve Y. velocity.dy > 0 = moving up; < 0 = falling.
        let yRes = sweepY(box: box, dy: velocity.dy, level: level)
        box.origin.y += yRes.resolvedDelta
        if yRes.hitWall {
            if velocity.dy > 0 {
                // ceiling — kill remaining upward motion + close hold window
                velocity.dy = 0
                jumpHoldFramesUsed = Constants.maxJumpHoldFrames
            } else {
                // floor — kill downward velocity
                velocity.dy = 0
            }
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
            // small upward bounce on death (y-up: positive = up), then gravity takes over.
            velocity.dy = 6
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
        else if !onGround {
            next = velocity.dy > 0 ? .jump : .fall
        }
        else if moving { next = .run }
        else { next = .idle }
        if next != currentAnim {
            // Land impact: was airborne, now on ground.
            if onGround, currentAnim == .fall || currentAnim == .jump {
                playLandSquash()
            }
            // Takeoff: was on ground, now ascending.
            if !onGround, next == .jump, currentAnim != .jump, currentAnim != .fall {
                playJumpSquash()
            }
            currentAnim = next
            playAnimation(next)
        }
    }
}

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}
