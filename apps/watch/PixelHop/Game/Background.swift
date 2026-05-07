import SpriteKit

/// Atmospheric layered backdrop for a Level. Sits behind the world tiles and
/// scrolls at fractional speeds to give depth — the further the layer, the
/// less it moves relative to the camera.
///
/// Layers (back-to-front):
///   1. Sky gradient — stationary (parallax 1.0)
///   2. Sun/moon disc — stationary
///   3. Far mountains — parallax ~0.18 (slow scroll)
///   4. Near mountains — parallax ~0.40
///   5. Drifting clouds — parallax ~0.55 + independent horizontal tween
///   6. Vignette overlay — stationary, soft dark corners
///
/// The backdrop nodes live as **children of the SKCameraNode**, so they
/// automatically follow whatever the camera is centred on. Per-frame `update`
/// applies horizontal offsets that produce the parallax effect.
@MainActor
final class Background {
    /// The root SKNode to attach to the camera.
    let node: SKNode

    private let theme: Level.Theme
    private let viewportSize: CGSize

    private let sky: SKSpriteNode
    private let sun: SKSpriteNode
    private let mountainFar: SKSpriteNode
    private let mountainNear: SKSpriteNode
    private let cloudLayer: SKNode
    private let vignette: SKSpriteNode

    /// Cumulative phase of cloud drift, separate from camera motion.
    private var cloudDriftPhase: CGFloat = 0

    init(theme: Level.Theme, viewportSize: CGSize) {
        self.theme = theme
        self.viewportSize = viewportSize
        self.node = SKNode()

        let suffix = theme.rawValue   // overworld / underground / sky / castle

        // ---- Sky ----
        let skyTex = SKTexture(imageNamed: "sky-\(suffix)")
        skyTex.filteringMode = .linear
        sky = SKSpriteNode(texture: skyTex, size: viewportSize)
        sky.zPosition = -100
        sky.position = .zero
        node.addChild(sky)

        // ---- Sun (placed top-right, drifts gently with parallax) ----
        let sunTex = SKTexture(imageNamed: "sun-\(suffix)")
        sunTex.filteringMode = .linear
        sun = SKSpriteNode(texture: sunTex)
        sun.zPosition = -95
        sun.alpha = 0.95
        sun.size = CGSize(width: 110, height: 110)
        sun.position = CGPoint(x: viewportSize.width * 0.28, y: viewportSize.height * 0.28)
        node.addChild(sun)

        // ---- Far mountains ----
        let mfTex = SKTexture(imageNamed: "mtn-far-\(suffix)")
        mfTex.filteringMode = .linear
        mountainFar = SKSpriteNode(texture: mfTex)
        mountainFar.zPosition = -90
        mountainFar.size = CGSize(width: viewportSize.width * 1.6, height: 130)
        mountainFar.position = CGPoint(x: 0, y: -viewportSize.height * 0.10)
        mountainFar.alpha = 0.75
        node.addChild(mountainFar)

        // ---- Near mountains ----
        let mnTex = SKTexture(imageNamed: "mtn-near-\(suffix)")
        mnTex.filteringMode = .linear
        mountainNear = SKSpriteNode(texture: mnTex)
        mountainNear.zPosition = -80
        mountainNear.size = CGSize(width: viewportSize.width * 1.7, height: 150)
        mountainNear.position = CGPoint(x: 0, y: -viewportSize.height * 0.18)
        mountainNear.alpha = 0.92
        node.addChild(mountainNear)

        // ---- Clouds: a few sprites placed around the upper region ----
        cloudLayer = SKNode()
        cloudLayer.zPosition = -70
        node.addChild(cloudLayer)
        Background.populateClouds(into: cloudLayer, viewportSize: viewportSize, theme: theme)

        // ---- Vignette overlay ----
        let vTex = SKTexture(imageNamed: "vignette")
        vTex.filteringMode = .linear
        vignette = SKSpriteNode(texture: vTex, size: viewportSize)
        vignette.zPosition = 200    // above everything in scene; below HUD which is SwiftUI
        vignette.alpha = 0.55
        vignette.position = .zero
        node.addChild(vignette)
    }

    private static func populateClouds(into parent: SKNode, viewportSize: CGSize, theme: Level.Theme) {
        // Underground / castle skip clouds entirely — just an extra dark gradient.
        guard theme == .overworld || theme == .sky else { return }
        let count = 4
        for i in 0..<count {
            let texName = (i % 2 == 0) ? "cloud-soft" : "cloud-big"
            let tex = SKTexture(imageNamed: texName)
            tex.filteringMode = .linear
            let cloud = SKSpriteNode(texture: tex)
            let scale = CGFloat.random(in: 0.7...1.2)
            cloud.size = CGSize(width: 110 * scale, height: 50 * scale)
            cloud.alpha = CGFloat.random(in: 0.7...0.9)
            // Distribute across viewport width and upper third
            let xOffset = CGFloat(i) * (viewportSize.width * 0.45) - viewportSize.width * 0.6
            let yOffset = viewportSize.height * CGFloat.random(in: 0.18...0.34)
            cloud.position = CGPoint(x: xOffset, y: yOffset)
            parent.addChild(cloud)
        }
    }

    /// Called every frame from `GameScene.update`. `camera` is in world coords.
    func update(cameraPosition camera: CGPoint, dt: CGFloat) {
        // Backdrop nodes are children of the camera node and start at (0,0)
        // = camera-local origin. Counter-translating them by `-camera.x *
        // (1 - factor)` makes them appear at world-x = camera.x * factor —
        // exactly the parallax we want. Sky/sun stay at 0 because their
        // factor = 1 (move 1:1 with camera).
        sun.position.x = -camera.x * (1.0 - 0.95) + viewportSize.width * 0.28 - viewportSize.width / 2
        // Re-anchor sun in upper-right with very gentle parallax (.95).
        sun.position = CGPoint(
            x: viewportSize.width * 0.30 + (-camera.x * 0.05),
            y: viewportSize.height * 0.28
        )

        let farFactor: CGFloat = 0.18
        mountainFar.position.x = -camera.x * (1 - farFactor)

        let nearFactor: CGFloat = 0.40
        mountainNear.position.x = -camera.x * (1 - nearFactor)

        // Cloud layer: slow horizontal drift independent of camera + parallax.
        cloudDriftPhase += dt * 6   // px/sec drift
        let cloudFactor: CGFloat = 0.55
        cloudLayer.position.x = -camera.x * (1 - cloudFactor) + cloudDriftPhase

        // Wrap cloud children individually so they don't run off forever.
        for child in cloudLayer.children {
            if child.position.x > viewportSize.width * 1.0 {
                child.position.x -= viewportSize.width * 2.0
            } else if child.position.x < -viewportSize.width * 1.0 {
                child.position.x += viewportSize.width * 2.0
            }
        }
    }
}
