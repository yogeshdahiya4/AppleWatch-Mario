import CoreGraphics
import SpriteKit

/// Common protocol for stompable / harmful entities.
@MainActor
protocol Enemy: AnyObject {
    var box: AABB { get set }
    var alive: Bool { get set }
    var node: SKNode { get }
    var killable: Bool { get }
    var stompable: Bool { get }
    /// Called every frame the enemy is on screen.
    func tick(level: Level)
    /// Player touched the enemy from above (stomp).
    func stomped()
}

@MainActor
final class Goomba: Enemy {
    var box: AABB
    var alive: Bool = true
    let node: SKNode
    private let sprite: SKSpriteNode
    private var velX: CGFloat = -0.6
    private var deathFramesLeft: Int = 0
    let killable: Bool = true
    let stompable: Bool = true

    init(at origin: CGPoint) {
        box = AABB(origin: origin, size: CGSize(width: 18, height: 18))
        node = SKNode()
        let renderSize = CGSize(width: 22, height: 22)
        let frames = SpriteRegistry.shared.enemyFrames(kind: .goomba)
        if let first = frames.first {
            sprite = SKSpriteNode(texture: first, size: renderSize)
            // Walk-cycle bobble.
            if frames.count > 1 {
                let walk = SKAction.animate(with: frames, timePerFrame: 0.18, resize: false, restore: true)
                sprite.run(.repeatForever(walk))
            }
        } else {
            sprite = SKSpriteNode(color: SKColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1), size: renderSize)
        }
        node.addChild(sprite)
        node.position = CGPoint(x: origin.x + box.size.width / 2,
                                  y: origin.y + box.size.height / 2)
    }

    func tick(level: Level) {
        guard alive else {
            deathFramesLeft -= 1
            if deathFramesLeft <= 0 { node.removeFromParent() }
            return
        }
        // Walk back and forth, reverse on wall
        let res = sweepX(box: box, dx: velX, level: level)
        box.origin.x += res.resolvedDelta
        if res.hitWall { velX = -velX }

        // Drop off ledges (Goombas don't, they walk straight). But avoid floating:
        let probe = AABB(origin: CGPoint(x: box.origin.x + (velX > 0 ? box.size.width : -1),
                                           y: box.origin.y - 1),
                          size: CGSize(width: 1, height: 1))
        if !anySolidOverlap(box: probe, level: level) {
            // turn around at ledge so AI looks smarter
            velX = -velX
        }

        // Apply gravity in case enemy was placed above ground
        var dy: CGFloat = 0
        let yRes = sweepY(box: box, dy: -3, level: level)
        dy = yRes.resolvedDelta
        box.origin.y += dy

        node.position = CGPoint(x: box.origin.x + box.size.width / 2,
                                 y: box.origin.y + box.size.height / 2)
    }

    func stomped() {
        guard alive else { return }
        alive = false
        sprite.yScale = 0.4
        deathFramesLeft = 12
    }
}

@MainActor
final class KoopaTroopa: Enemy {
    enum Variant { case green, red }
    var box: AABB
    var alive: Bool = true
    let node: SKNode
    private let sprite: SKSpriteNode
    private var velX: CGFloat
    private var inShell: Bool = false
    let variant: Variant
    let killable: Bool = true
    let stompable: Bool = true

    init(at origin: CGPoint, variant: Variant) {
        self.variant = variant
        self.box = AABB(origin: origin, size: CGSize(width: 18, height: 22))
        self.velX = (variant == .green) ? -0.5 : -0.7
        self.node = SKNode()
        let renderSize = CGSize(width: 22, height: 26)
        let kind: EntitySpawn.Kind = variant == .green ? .koopaGreen : .koopaRed
        let frames = SpriteRegistry.shared.enemyFrames(kind: kind)
        if let first = frames.first {
            self.sprite = SKSpriteNode(texture: first, size: renderSize)
            if frames.count > 1 {
                let walk = SKAction.animate(with: frames, timePerFrame: 0.18, resize: false, restore: true)
                sprite.run(.repeatForever(walk))
            }
        } else {
            let color: SKColor = variant == .green
                ? SKColor(red: 0.20, green: 0.78, blue: 0.30, alpha: 1)
                : SKColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1)
            self.sprite = SKSpriteNode(color: color, size: renderSize)
        }
        node.addChild(sprite)
        node.position = CGPoint(x: origin.x + box.size.width / 2,
                                  y: origin.y + box.size.height / 2)
    }

    func tick(level: Level) {
        guard alive else { node.removeFromParent(); return }
        let res = sweepX(box: box, dx: velX, level: level)
        box.origin.x += res.resolvedDelta
        if res.hitWall { velX = -velX }

        // Red variant respects ledges, green does not
        if variant == .red {
            let probe = AABB(origin: CGPoint(x: box.origin.x + (velX > 0 ? box.size.width : -1),
                                                y: box.origin.y - 1),
                              size: CGSize(width: 1, height: 1))
            if !anySolidOverlap(box: probe, level: level) { velX = -velX }
        }

        let yRes = sweepY(box: box, dy: -3, level: level)
        box.origin.y += yRes.resolvedDelta
        node.position = CGPoint(x: box.origin.x + box.size.width / 2,
                                 y: box.origin.y + box.size.height / 2)
    }

    func stomped() {
        if !inShell {
            inShell = true
            box.size.height = 10
            sprite.yScale = 0.6
            velX = 0
        } else {
            // Stomp again -> shell goes flying
            velX = velX == 0 ? 4 : -velX
        }
    }
}
