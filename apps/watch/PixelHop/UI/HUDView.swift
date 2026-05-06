import SwiftUI

/// Top-of-screen HUD: score, coins, lives, time. Designed to read at a glance.
struct HUDView: View {
    let state: GameScene.HUDState

    var body: some View {
        HStack(spacing: 6) {
            // Lives
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("\(state.lives)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Spacer(minLength: 4)

            // Coins
            HStack(spacing: 2) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(state.coins)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Spacer(minLength: 4)

            // Time
            HStack(spacing: 2) {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
                Text("\(state.timeRemaining)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.45))
                .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.5))
        )
        .padding(.horizontal, 8)
    }
}
