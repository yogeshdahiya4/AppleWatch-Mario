import SpriteKit
import Combine

/// The orchestrator: builds the world from a Level, runs the per-frame loop,
/// and routes input → player + enemies. Owns the camera.
@MainActor
final class GameScene: SKScene {
    // MARK: - Public state surface (read by SwiftUI HUD)

    @Published private(set) var hudState: HUDState = .start

    struct HUDState {
        var score: Int = 0
        var coins: Int = 0
        var lives: Int = 3
        var timeRemaining: Int = 0
        var levelLabel: String = ""
        var paused: Bool = false
        static let start = HUDState()
    }

    /// Fired once when the level reaches a terminal state.
    let levelEnded = PassthroughSubject<GameRunResult, Never>()

    // MARK: - Inputs
    let input: InputController

    // MARK: - World
    private let level: Level
    private var player: Player!
    private var enemies: [any Enemy] = []
    private var coins: [SKNode] = []
    private let camera_: GameCamera = GameCamera()
    private let worldNode = SKNode()
    private let entitiesNode = SKNode()
    private let coinsNode = SKNode()

    // MARK: - Counters
    private var scoreTotal = 0
    private var coinCount = 0
    private var livesLeft = 3
    private var timeRemainingMs: Int
    private var startTimeMs: Int = 0
    private var levelClock: TimeInterval = 0
    private var paused_: Bool = false

    // MARK: - Subscriptions
    private var subs = Set<AnyCancellable>()

    init(level: Level, input: InputController, viewportSize: CGSize) {
        self.level = level
        self.input = input
        self.timeRemainingMs = level.timeLimit * 1000
        super.init(size: viewportSize)
        scaleMode = .resizeFill
        backgroundColor = bgColor(for: level.theme)
    }

    required init?(coder _: NSCoder) { fatalError() }

    override func sceneDidLoad() {
        super.sceneDidLoad()

        addChild(worldNode)
        worldNode.addChild(coinsNode)
        worldNode.addChild(entitiesNode)

        buildTiles()
        spawnPlayer()
        spawnEntities()

        camera = camera_.node
        camera_.levelBounds = CGRect(
            x: 0, y: 0,
            width: CGFloat(level.width) * Constants.tileSize,
            height: CGFloat(level.height) * Constants.tileSize
        )
        camera_.node.position = player.node.position
        addChild(camera_.node)

        wireInput()
        hudState = HUDState(
            score: 0, coins: 0, lives: livesLeft,
            timeRemaining: level.timeLimit,
            levelLabel: "\(level.id.rawValue) \(level.id.displayName)",
            paused: false
        )
        startTimeMs = Int(Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - Build

    private func bgColor(for theme: Level.Theme) -> SKColor {
        switch theme {
        case .overworld:   return SKColor(red: 0.42, green: 0.65, blue: 0.99, alpha: 1.0)
        case .underground: return SKColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1.0)
        case .sky:         return SKColor(red: 0.62, green: 0.80, blue: 0.98, alpha: 1.0)
        case .castle:      return SKColor(red: 0.10, green: 0.05, blue: 0.06, alpha: 1.0)
        }
    }

    private func tileColor(_ tile: Tile, theme: Level.Theme) -> SKColor {
        switch tile {
        case .ground:
            return theme == .underground ? SKColor(red: 0.30, green: 0.20, blue: 0.10, alpha: 1)
                 : theme == .castle ? SKColor(red: 0.30, green: 0.30, blue: 0.34, alpha: 1)
                 : SKColor(red: 0.50, green: 0.30, blue: 0.10, alpha: 1)
        case .brick: return SKColor(red: 0.62, green: 0.30, blue: 0.20, alpha: 1)
        case .question: return SKColor(red: 0.96, green: 0.78, blue: 0.20, alpha: 1)
        case .hard: return SKColor(white: 0.5, alpha: 1)
        case .pipeTopL, .pipeTopR, .pipeBodyL, .pipeBodyR: return SKColor(red: 0.20, green: 0.65, blue: 0.20, alpha: 1)
        case .cloudL, .cloudM, .cloudR: return SKColor(white: 1, alpha: 0.92)
        case .lava: return SKColor(red: 0.90, green: 0.20, blue: 0.10, alpha: 1)
        case .water: return SKColor(red: 0.20, green: 0.40, blue: 0.90, alpha: 1)
        case .castle: return SKColor(white: 0.4, alpha: 1)
        case .flagPole: return SKColor(white: 0.85, alpha: 1)
        case .flagTop: return SKColor(red: 0.10, green: 0.85, blue: 0.30, alpha: 1)
        case .checkpoint: return SKColor(red: 0.5, green: 0.5, blue: 0.95, alpha: 1)
        case .spikes: return SKColor(white: 0.7, alpha: 1)
        case .empty: return .clear
        }
    }

    private func buildTiles() {
        let ts = Constants.tileSize
        let tilesNode = SKNode()
        worldNode.addChild(tilesNode)
        let registry = SpriteRegistry.shared
        for x in 0..<level.width {
            for y in 0..<level.height {
                let t = level.tile(at: TilePoint(x: x, y: y))
                if t == .empty { continue }
                let node: SKSpriteNode
                if let tex = registry.texture(for: t, theme: level.theme) {
                    node = SKSpriteNode(texture: tex, size: CGSize(width: ts, height: ts))
                } else {
                    node = SKSpriteNode(color: tileColor(t, theme: level.theme), size: CGSize(width: ts, height: ts))
                }
                node.anchorPoint = CGPoint(x: 0, y: 0)
                node.position = CGPoint(x: CGFloat(x) * ts, y: CGFloat(y) * ts)
                tilesNode.addChild(node)
            }
        }
    }

    private func spawnPlayer() {
        let ts = Constants.tileSize
        let spawnPx = CGPoint(x: CGFloat(level.spawn.x) * ts + 2,
                                y: CGFloat(level.spawn.y) * ts + 2)
        player = Player(spawn: spawnPx, atlas: nil)
        worldNode.addChild(player.node)
    }

    private func spawnEntities() {
        let ts = Constants.tileSize
        for spawn in level.entities {
            let p = CGPoint(x: CGFloat(spawn.tile.x) * ts + 2,
                              y: CGFloat(spawn.tile.y) * ts + 2)
            switch spawn.kind {
            case .goomba:
                let g = Goomba(at: p)
                enemies.append(g)
                entitiesNode.addChild(g.node)
            case .koopaGreen:
                let k = KoopaTroopa(at: p, variant: .green)
                enemies.append(k)
                entitiesNode.addChild(k.node)
            case .koopaRed:
                let k = KoopaTroopa(at: p, variant: .red)
                enemies.append(k)
                entitiesNode.addChild(k.node)
            case .coin:
                let c = SKShapeNode(circleOfRadius: 4)
                c.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.10, alpha: 1)
                c.strokeColor = .clear
                c.position = CGPoint(x: p.x + 6, y: p.y + 6)
                c.userData = ["kind": "coin"]
                coinsNode.addChild(c)
                coins.append(c)
            case .mushroom, .fireFlower, .oneUp:
                let m = SKSpriteNode(color: spawn.kind == .mushroom ? SKColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1)
                                            : spawn.kind == .fireFlower ? SKColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1)
                                            : SKColor(red: 0.20, green: 0.78, blue: 0.30, alpha: 1),
                                       size: CGSize(width: 12, height: 12))
                m.position = CGPoint(x: p.x + 6, y: p.y + 6)
                m.userData = ["kind": "powerUp:\(spawn.kind)"]
                coinsNode.addChild(m)
                coins.append(m)
            case .piranha, .lakitu, .spiny, .bossBowserStomp:
                // Placeholder enemies for now — tracked via simple sprite + box.
                // Real AI in a follow-up; for v1 we render and skip kill logic.
                let e = SKShapeNode(rectOf: CGSize(width: 12, height: 12))
                e.fillColor = SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1)
                e.strokeColor = .clear
                e.position = CGPoint(x: p.x + 6, y: p.y + 6)
                entitiesNode.addChild(e)
            }
        }
    }

    private func wireInput() {
        input.jumpEvents
            .sink { [weak self] _ in self?.pendingJumpFlick = true }
            .store(in: &subs)
        input.pauseEvents
            .sink { [weak self] in self?.togglePause() }
            .store(in: &subs)
    }

    private var pendingJumpFlick = false

    // MARK: - Per-frame update

    private var lastUpdateTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        guard !paused_ else { return }

        // Frame delta (seconds). On simulator/watch we'd cap to 1/30.
        let dt = lastUpdateTime == 0 ? 0 : min(0.05, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        levelClock += dt

        // Time remaining tick
        timeRemainingMs = max(0, timeRemainingMs - Int(dt * 1000))

        // Player
        let center = player.tick(
            moveAxis: input.moveAxis,
            jumpHeld: input.jumpHeld,
            jumpFlicked: pendingJumpFlick,
            level: level
        )
        pendingJumpFlick = false

        // Enemies
        for e in enemies where e.alive {
            e.tick(level: level)
        }

        // Player-vs-enemy
        for e in enemies where e.alive {
            if player.box.intersects(e.box), player.alive {
                let stompedFromAbove = (player.box.minY > e.box.minY + e.box.size.height * 0.5)
                                        && (player.velocity.dy < 0)
                if stompedFromAbove, e.stompable {
                    e.stomped()
                    scoreTotal += 100
                    Haptics.stomp()
                    player.velocity.dy = 3.5    // small upward bounce off the enemy (y-up)
                } else {
                    player.takeDamage(fatal: false)
                    Haptics.hurt()
                }
            }
        }

        // Coin collection
        for (i, coin) in coins.enumerated().reversed() {
            let pos = coin.position
            let coinBox = AABB(origin: CGPoint(x: pos.x - 4, y: pos.y - 4),
                                 size: CGSize(width: 8, height: 8))
            if player.box.intersects(coinBox) {
                let kind = coin.userData?["kind"] as? String ?? "coin"
                if kind == "coin" {
                    coinCount += 1
                    scoreTotal += 200
                    Haptics.coin()
                } else {
                    Haptics.powerUp()
                    if kind.contains("mushroom"), player.mode == .small { player.mode = .big }
                    if kind.contains("fireFlower") { player.mode = .fire }
                    if kind.contains("oneUp") { livesLeft += 1 }
                    scoreTotal += 1000
                }
                coin.removeFromParent()
                coins.remove(at: i)
            }
        }

        // Goal reached?
        let goalBox = AABB(
            origin: CGPoint(x: CGFloat(level.goal.x) * Constants.tileSize,
                             y: CGFloat(level.goal.y) * Constants.tileSize),
            size: CGSize(width: 16, height: 96)
        )
        if player.box.intersects(goalBox), player.alive {
            finishLevel(succeeded: true)
        }

        // Out of time / fell off the world
        if timeRemainingMs <= 0 || player.box.minY < -64 {
            if player.alive { player.takeDamage(fatal: true) }
        }

        if !player.alive, player.box.minY < -200 {
            finishLevel(succeeded: false)
        }

        // Camera
        camera_.follow(center, viewportSize: size)

        // Publish HUD
        hudState = HUDState(
            score: scoreTotal,
            coins: coinCount,
            lives: livesLeft,
            timeRemaining: timeRemainingMs / 1000,
            levelLabel: hudState.levelLabel,
            paused: paused_
        )
    }

    private func finishLevel(succeeded: Bool) {
        guard !ended else { return }
        ended = true
        let elapsedMs = max(1, Int(Date().timeIntervalSince1970 * 1000) - startTimeMs)
        let timeBonus = succeeded ? max(0, timeRemainingMs / 20) : 0
        let result = GameRunResult(
            level: level.id,
            score: scoreTotal + timeBonus,
            coins: coinCount,
            timeMs: elapsedMs,
            died: !succeeded,
            worldCompleted: false   // aggregator handles cross-level
        )
        if succeeded {
            Haptics.levelClear()
        }
        levelEnded.send(result)
    }

    private var ended = false

    // MARK: - Pause

    func togglePause() {
        paused_.toggle()
        isPaused = paused_
        hudState.paused = paused_
    }
}
