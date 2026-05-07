import SpriteKit

/// Centralised factory for the game's `SKEmitterNode`-based particle effects.
/// Each function returns a fully configured emitter that's safe to add to a
/// scene. Per-effect particle counts are capped so the total active particle
/// budget on the watch stays modest (well under 100 at any moment).
enum Effects {
    /// Tiny greyish puff at the player's feet on landing / direction change.
    static func dustPuff(at position: CGPoint) -> SKEmitterNode {
        let n = SKEmitterNode()
        n.particleTexture = circleTexture(diameter: 4, color: .white)
        n.particleColor = SKColor(white: 0.85, alpha: 1)
        n.particleColorBlendFactor = 1.0
        n.particleColorAlphaSpeed = -2.5
        n.particleAlpha = 0.85
        n.particleBirthRate = 120
        n.numParticlesToEmit = 8
        n.particleLifetime = 0.35
        n.particleScale = 0.6
        n.particleScaleSpeed = -1.6
        n.particleSpeed = 28
        n.particleSpeedRange = 14
        n.emissionAngle = .pi / 2
        n.emissionAngleRange = .pi
        n.yAcceleration = -50
        n.position = position
        n.zPosition = 5
        return n
    }

    /// Coin pickup — yellow sparkle ring expanding outward.
    static func coinSparkle(at position: CGPoint) -> SKEmitterNode {
        let n = SKEmitterNode()
        n.particleTexture = circleTexture(diameter: 5, color: .white)
        n.particleColor = SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1)
        n.particleColorBlendFactor = 1.0
        n.particleAlpha = 1.0
        n.particleAlphaSpeed = -2.0
        n.particleBirthRate = 220
        n.numParticlesToEmit = 16
        n.particleLifetime = 0.5
        n.particleScale = 0.5
        n.particleScaleSpeed = -0.8
        n.particleSpeed = 70
        n.particleSpeedRange = 30
        n.emissionAngle = 0
        n.emissionAngleRange = .pi * 2  // full circle
        n.position = position
        n.zPosition = 6
        return n
    }

    /// Confetti — slowly falling multi-coloured rectangles for level clear.
    static func confetti(at position: CGPoint, width: CGFloat) -> SKEmitterNode {
        let n = SKEmitterNode()
        n.particleTexture = rectTexture(size: CGSize(width: 4, height: 6), color: .white)
        // Colour ramp via colorSequence
        let stops: [SKColor] = [
            SKColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1),
            SKColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1),
            SKColor(red: 0.20, green: 0.85, blue: 0.40, alpha: 1),
            SKColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1),
            SKColor(red: 0.85, green: 0.30, blue: 0.95, alpha: 1),
        ]
        n.particleColorSequence = SKKeyframeSequence(keyframeValues: stops, times: [0, 0.25, 0.5, 0.75, 1.0])
        n.particleColorBlendFactor = 1.0
        n.particleAlpha = 1.0
        n.particleAlphaSpeed = -0.4
        n.particleBirthRate = 80
        n.numParticlesToEmit = 60
        n.particleLifetime = 2.0
        n.particleLifetimeRange = 0.6
        n.particleScale = 1.0
        n.particleScaleRange = 0.4
        n.particleSpeed = 60
        n.particleSpeedRange = 40
        n.emissionAngle = -.pi / 2
        n.emissionAngleRange = .pi / 3
        n.particleRotationSpeed = 4
        n.particleRotationRange = .pi
        n.yAcceleration = -120
        n.position = position
        n.particlePositionRange = CGVector(dx: width, dy: 0)
        n.zPosition = 50
        return n
    }

    /// Hurt sparks — short fast red bursts.
    static func hurtSparks(at position: CGPoint) -> SKEmitterNode {
        let n = SKEmitterNode()
        n.particleTexture = circleTexture(diameter: 4, color: .white)
        n.particleColor = SKColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1)
        n.particleColorBlendFactor = 1.0
        n.particleAlpha = 1.0
        n.particleAlphaSpeed = -3.0
        n.particleBirthRate = 200
        n.numParticlesToEmit = 12
        n.particleLifetime = 0.3
        n.particleScale = 0.5
        n.particleScaleSpeed = -1.5
        n.particleSpeed = 90
        n.particleSpeedRange = 40
        n.emissionAngleRange = .pi * 2
        n.position = position
        n.zPosition = 6
        return n
    }

    /// Castle ambient — slow-rising orange embers.
    static func lavaEmber(in rect: CGRect) -> SKEmitterNode {
        let n = SKEmitterNode()
        n.particleTexture = circleTexture(diameter: 3, color: .white)
        n.particleColor = SKColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1)
        n.particleColorBlendFactor = 1.0
        n.particleAlpha = 0.9
        n.particleAlphaSpeed = -0.4
        n.particleBirthRate = 6                  // very slow
        n.particleLifetime = 2.5
        n.particleLifetimeRange = 0.8
        n.particleScale = 0.5
        n.particleScaleRange = 0.2
        n.particleScaleSpeed = -0.15
        n.particleSpeed = 18
        n.particleSpeedRange = 10
        n.emissionAngle = .pi / 2                // upward
        n.emissionAngleRange = .pi / 8
        n.position = CGPoint(x: rect.midX, y: rect.minY)
        n.particlePositionRange = CGVector(dx: rect.width, dy: 0)
        n.zPosition = 3
        return n
    }

    // MARK: - Helpers

    /// Tiny soft-edged white disc, cached. CoreGraphics directly because
    /// UIGraphicsImageRenderer is iOS-only.
    private static var circleCache: [Int: SKTexture] = [:]
    private static func circleTexture(diameter d: Int, color: SKColor) -> SKTexture {
        if let cached = circleCache[d] { return cached }
        let tex = makeBitmapTexture(width: d, height: d, color: color, draw: { ctx, size in
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        })
        circleCache[d] = tex
        return tex
    }

    private static var rectCache: [String: SKTexture] = [:]
    private static func rectTexture(size: CGSize, color: SKColor) -> SKTexture {
        let key = "\(Int(size.width))x\(Int(size.height))"
        if let cached = rectCache[key] { return cached }
        let tex = makeBitmapTexture(width: Int(size.width), height: Int(size.height), color: color, draw: { ctx, sz in
            ctx.fill(CGRect(origin: .zero, size: sz))
        })
        rectCache[key] = tex
        return tex
    }

    private static func makeBitmapTexture(width w: Int, height h: Int, color: SKColor,
                                            draw: (CGContext, CGSize) -> Void) -> SKTexture {
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                    bitsPerComponent: 8, bytesPerRow: 4 * w,
                                    space: cs, bitmapInfo: bitmapInfo) else {
            return SKTexture()
        }
        ctx.setFillColor(color.cgColor)
        draw(ctx, CGSize(width: w, height: h))
        guard let img = ctx.makeImage() else { return SKTexture() }
        let tex = SKTexture(cgImage: img)
        tex.filteringMode = .linear
        return tex
    }
}
