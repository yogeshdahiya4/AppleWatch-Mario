import SwiftUI

@main
struct PixelHopApp: App {
    @StateObject private var session = GameSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
    }
}

/// Top-level state container shared across views.
/// SwiftUI's environmentObject pattern keeps us out of singleton hell while
/// letting any screen reach for the player's identity, hi-scores, and
/// leaderboard cache.
@MainActor
final class GameSession: ObservableObject {
    @Published var deviceIdentity: DeviceIdentity?
    @Published var save: GameSave = .empty
    @Published var pendingSubmissions: [PendingScore] = []

    let api: APIClient
    let scoreSubmitter: ScoreSubmitter

    init() {
        self.api = APIClient()
        self.scoreSubmitter = ScoreSubmitter(api: api)
        self.deviceIdentity = DeviceIdentity.loadFromKeychain()
        self.save = GameSave.load()
    }

    func bootstrap() async {
        if deviceIdentity == nil {
            // First launch — defer registration until user picks a nickname.
            return
        }
        await scoreSubmitter.flushPending(identity: deviceIdentity!)
    }
}
