import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: GameSession
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if session.deviceIdentity == nil {
                    NicknameOnboardingView { newId in
                        session.deviceIdentity = newId
                    }
                } else {
                    MainMenuView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .play(let level):
                    GameContainerView(startingLevel: level)
                case .levelSelect:
                    LevelSelectView()
                case .leaderboard(let scope):
                    LeaderboardView(scope: scope)
                case .settings:
                    SettingsView()
                case .gameOver(let result):
                    GameOverView(result: result)
                case .worldComplete(let result):
                    WorldCompleteView(result: result)
                }
            }
        }
        .task {
            await session.bootstrap()
            #if DEBUG
            // QA shortcut: jump straight to a route after auto-onboard.
            // Set via `SIMCTL_CHILD_PIXELHOP_DEBUG_ROUTE=...` (also needs AUTO_ONBOARD).
            // Accepted values: "1-1" / "1-2" / "1-3" / "1-4" → play; "levels", "leaderboard", "settings".
            if let route = ProcessInfo.processInfo.environment["PIXELHOP_DEBUG_ROUTE"],
               session.deviceIdentity != nil {
                try? await Task.sleep(for: .milliseconds(300))
                if let id = LevelID(rawValue: route) {
                    path.append(AppRoute.play(id))
                } else if route == "levels" {
                    path.append(AppRoute.levelSelect)
                } else if route == "leaderboard" {
                    path.append(AppRoute.leaderboard(.global))
                } else if route == "settings" {
                    path.append(AppRoute.settings)
                }
            }
            #endif
        }
    }
}

enum AppRoute: Hashable {
    case play(LevelID)
    case levelSelect
    case leaderboard(LeaderboardScope)
    case settings
    case gameOver(GameRunResult)
    case worldComplete(GameRunResult)
}

enum LeaderboardScope: Hashable {
    case level(LevelID)
    case global
}
