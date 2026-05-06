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
