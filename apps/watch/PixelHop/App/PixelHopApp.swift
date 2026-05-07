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
        #if DEBUG
        // Sim/QA shortcut: auto-register a throwaway device when this env var
        // is set (typically via `xcrun simctl launch ... --env PIXELHOP_DEBUG_AUTO_ONBOARD=1`).
        // Lets us boot straight into the menu + drive the game without typing
        // a nickname on a watch keyboard simctl can't reach.
        if deviceIdentity == nil,
           ProcessInfo.processInfo.environment["PIXELHOP_DEBUG_AUTO_ONBOARD"] == "1" {
            do {
                let nick = "demo\(Int.random(in: 1000...9999))"
                let id = try await DeviceIdentity.registerNew(nickname: nick, api: api)
                try? id.persistToKeychain()
                deviceIdentity = id
            } catch {
                // Fall through; manual onboarding still works.
            }
        }
        #endif
        if let id = deviceIdentity {
            await scoreSubmitter.flushPending(identity: id)
        }
    }
}
