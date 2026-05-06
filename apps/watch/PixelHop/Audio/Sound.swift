import AVFoundation
import Foundation

/// Tiny SFX bank. Audio files (CC0) live in Resources/Sounds.
/// We intentionally use AVAudioPlayer per clip — AVAudioEngine is more
/// powerful but for ~6 short SFX it's overkill and burns more battery.
@MainActor
final class Sound {
    enum Clip: String, CaseIterable {
        case jump, coin, stomp, hurt, powerUp, levelClear
    }

    private var players: [Clip: AVAudioPlayer] = [:]
    private var enabled: Bool

    init(enabled: Bool = true) {
        self.enabled = enabled
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient, mode: .default, options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        for clip in Clip.allCases {
            if let url = Bundle.main.url(forResource: clip.rawValue, withExtension: "wav"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                p.volume = 0.8
                players[clip] = p
            }
        }
    }

    func play(_ clip: Clip) {
        guard enabled, let p = players[clip] else { return }
        if p.isPlaying { p.currentTime = 0 } else { p.play() }
    }

    func setEnabled(_ on: Bool) { enabled = on }
}
