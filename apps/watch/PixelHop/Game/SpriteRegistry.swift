import SpriteKit

/// Maps `Tile` enum values to actual sprite textures from the Kenney Pixel
/// Platformer pack. Falls back to flat-color rectangles when sprites are not
/// available (testing / pre-asset-import).
///
/// Sprite name conventions per Kenney's pack (tile_NNNN.png):
/// (These mappings are approximations — fine-tune as needed by inspecting
/// tilemap.png in the asset bundle.)
@MainActor
final class SpriteRegistry {
    static let shared = SpriteRegistry()

    private let tilesAtlas: SKTextureAtlas?
    private let characterAtlas: SKTextureAtlas?

    private init() {
        // The watchOS bundle ships compiled atlases as `.atlasc`. SKTextureAtlas
        // resolves them by name lazily. **Do not** call preloadTextureAtlases
        // here — it crashes on watchOS in SKTextureAtlas getSupportedPostfixes
        // because UIScreen.currentMode returns nil and a downstream NSDictionary
        // lookup explodes. Lazy load is fine; the first frame may stutter but
        // won't crash.
        self.tilesAtlas = SKTextureAtlas(named: "Tiles")
        self.characterAtlas = SKTextureAtlas(named: "Characters")
    }

    /// Returns a texture for the given tile, or nil if no sprite is wired up
    /// and we should fall back to a colored rectangle.
    func texture(for tile: Tile, theme: Level.Theme) -> SKTexture? {
        guard let atlas = tilesAtlas, !atlas.textureNames.isEmpty else { return nil }
        let name: String? = {
            switch (tile, theme) {
            case (.ground, .underground): return "tile_0008"
            case (.ground, .castle):      return "tile_0010"
            case (.ground, _):            return "tile_0001"
            case (.brick, _):             return "tile_0009"
            case (.question, _):          return "tile_0028"
            case (.hard, _):              return "tile_0011"
            case (.pipeTopL, _):          return "tile_0066"
            case (.pipeTopR, _):          return "tile_0067"
            case (.pipeBodyL, _):         return "tile_0084"
            case (.pipeBodyR, _):         return "tile_0085"
            case (.cloudL, _):            return "tile_0099"
            case (.cloudM, _):            return "tile_0100"
            case (.cloudR, _):            return "tile_0101"
            case (.lava, _):              return "tile_0017"
            case (.water, _):             return "tile_0006"
            case (.castle, _):            return "tile_0030"
            case (.flagPole, _):          return "tile_0131"
            case (.flagTop, _):           return "tile_0132"
            case (.checkpoint, _):        return "tile_0023"
            case (.spikes, _):            return "tile_0070"
            case (.empty, _):             return nil
            }
        }()
        guard let name else { return nil }
        let names = atlas.textureNames
        if names.contains(name) {
            let t = atlas.textureNamed(name)
            t.filteringMode = .nearest    // pixel-art crisp scaling
            return t
        }
        return nil
    }

    func playerTexture(state: String) -> SKTexture? {
        playerFrames(state: state).first
    }

    /// Frame sequence for the requested player state. Empty = caller falls back.
    /// Both the `Tiles` and `Characters` atlases contain `tile_NNNN.png` files.
    /// The names collide, so we explicitly target `Characters/tile_NNNN` —
    /// SpriteKit resolves that path-style name to the right atlas.
    func playerFrames(state: String) -> [SKTexture] {
        let names: [String]
        switch state {
        case "idle":  names = ["tile_0000"]
        case "run":   names = ["tile_0000", "tile_0001"]
        case "jump":  names = ["tile_0001"]
        case "fall":  names = ["tile_0001"]
        case "hurt":  names = ["tile_0000"]
        case "dead":  names = ["tile_0001"]
        default:      names = ["tile_0000"]
        }
        return names.map { resolveCharacter($0) }
    }

    /// Look up a character-pack texture by its short name. Tries the
    /// `Characters` atlas first, then falls back to the path-style name
    /// `Characters/tile_NNNN`, which SpriteKit also resolves on watchOS.
    private func resolveCharacter(_ name: String) -> SKTexture {
        if let atlas = characterAtlas {
            let t = atlas.textureNamed(name)
            t.filteringMode = .nearest
            return t
        }
        let t = SKTexture(imageNamed: "Characters/\(name)")
        t.filteringMode = .nearest
        return t
    }

    /// Frame sequence for an enemy. `kind` identifies the species; we map to
    /// the closest visual equivalent in the Kenney pack.
    func enemyFrames(kind: EntitySpawn.Kind) -> [SKTexture] {
        let names: [String]
        switch kind {
        case .goomba:       names = ["tile_0011", "tile_0012"]
        case .koopaGreen:   names = ["tile_0004", "tile_0005"]
        case .koopaRed:     names = ["tile_0015", "tile_0016"]
        case .piranha:      names = ["tile_0013", "tile_0014"]
        case .lakitu:       names = ["tile_0023"]
        case .spiny:        names = ["tile_0024"]
        case .bossBowserStomp: names = ["tile_0008"]
        case .mushroom:     names = ["tile_0011"]
        case .fireFlower:   names = ["tile_0013"]
        case .oneUp:        names = ["tile_0011"]
        case .coin:         return []
        }
        return names.map { resolveCharacter($0) }
    }
}
