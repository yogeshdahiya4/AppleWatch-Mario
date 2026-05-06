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
    private var loaded: Bool { tilesAtlas != nil }

    private init() {
        // SpriteKit autoatlases any folder named "X.atlas" in the app bundle.
        // If the atlas isn't present (still in pre-asset-import mode), we fall
        // back to flat colors at the call site.
        if let _ = Bundle.main.url(forResource: "Tiles", withExtension: "atlas") {
            self.tilesAtlas = SKTextureAtlas(named: "Tiles")
        } else if Bundle.main.url(forResource: "tile_0000", withExtension: "png") != nil {
            self.tilesAtlas = SKTextureAtlas(named: "Tiles")
        } else {
            self.tilesAtlas = nil
        }
        if Bundle.main.url(forResource: "Characters", withExtension: "atlas") != nil {
            self.characterAtlas = SKTextureAtlas(named: "Characters")
        } else {
            self.characterAtlas = nil
        }
    }

    /// Returns a texture for the given tile, or nil if no sprite is wired up
    /// and we should fall back to a colored rectangle.
    func texture(for tile: Tile, theme: Level.Theme) -> SKTexture? {
        guard let atlas = tilesAtlas else { return nil }
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
        guard let atlas = characterAtlas else { return nil }
        let candidates: [String]
        switch state {
        case "idle": candidates = ["tile_0000", "character_blue_idle", "character_pink_idle"]
        case "run":  candidates = ["tile_0001", "character_blue_walk_a"]
        case "jump": candidates = ["tile_0002", "character_blue_jump"]
        default:     candidates = ["tile_0000"]
        }
        let names = atlas.textureNames
        for c in candidates where names.contains(c) {
            let t = atlas.textureNamed(c)
            t.filteringMode = .nearest
            return t
        }
        return nil
    }
}
