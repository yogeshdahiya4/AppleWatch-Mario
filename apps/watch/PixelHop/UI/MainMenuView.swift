import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var session: GameSession

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                titleHeader

                NavigationLink(value: AppRoute.play(.world1_1)) {
                    BigButton(label: "Play", icon: "play.fill", tint: .green)
                }

                NavigationLink(value: AppRoute.levelSelect) {
                    BigButton(label: "Levels", icon: "square.grid.2x2.fill", tint: .blue)
                }

                NavigationLink(value: AppRoute.leaderboard(.global)) {
                    BigButton(label: "Leaderboard", icon: "trophy.fill", tint: .yellow)
                }

                NavigationLink(value: AppRoute.settings) {
                    BigButton(label: "Settings", icon: "gearshape.fill", tint: .gray)
                }

                if session.save.bestWorldScore > 0 {
                    Text("Best: \(session.save.bestWorldScore)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleHeader: some View {
        VStack(spacing: 0) {
            Text("PixelHop")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let nick = session.deviceIdentity?.nickname {
                Text("@\(nick)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 6)
    }
}

struct BigButton: View {
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.55), lineWidth: 1)
                )
        )
        .foregroundStyle(tint)
    }
}
