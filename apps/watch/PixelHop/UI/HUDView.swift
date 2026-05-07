import SwiftUI

/// Top-of-screen HUD with score-pop animation when the score changes.
struct HUDView: View {
    let state: GameScene.HUDState

    @State private var scorePopScale: CGFloat = 1.0
    @State private var coinsPopScale: CGFloat = 1.0
    @State private var lastCoins: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            chip(icon: "heart.fill", value: "\(state.lives)", tint: .red)
            chip(icon: "circle.fill", value: "\(state.coins)", tint: .yellow)
                .scaleEffect(coinsPopScale)
            Spacer(minLength: 4)
            chip(icon: "timer", value: "\(state.timeRemaining)", tint: .cyan)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(.black.opacity(0.55))
                .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.5))
        )
        .padding(.horizontal, 6)
        .onChange(of: state.coins) { _, newCoins in
            guard newCoins != lastCoins else { return }
            lastCoins = newCoins
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                coinsPopScale = 1.35
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    coinsPopScale = 1.0
                }
            }
        }
    }

    @ViewBuilder
    private func chip(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}
