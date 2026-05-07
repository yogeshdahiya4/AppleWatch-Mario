import SwiftUI

struct GameOverView: View {
    let result: GameRunResult
    @Environment(\.dismiss) private var dismiss
    @State private var iconScale: CGFloat = 0.4
    @State private var iconRotation: Double = -25

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "xmark.octagon.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundStyle(.red)
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
                .shadow(color: .red.opacity(0.5), radius: 10)
            Text("Game Over")
                .font(.system(size: 20, weight: .black, design: .rounded))
            Text("Score \(result.score)")
                .font(.caption).foregroundStyle(.secondary)
            Button("Try again") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                iconScale = 1.0
                iconRotation = 0
            }
        }
    }
}

struct WorldCompleteView: View {
    let result: GameRunResult
    @Environment(\.dismiss) private var dismiss
    @State private var trophyScale: CGFloat = 0.1
    @State private var glowAmount: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(trophyScale)
                .shadow(color: .yellow.opacity(glowAmount), radius: 12)
            Text("World Complete!")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
            Text("Score \(result.score)").font(.caption).fontWeight(.semibold)
            Text("Coins \(result.coins) • Time \(result.timeMs / 1000)s").font(.caption2).foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                trophyScale = 1.0
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2)) {
                glowAmount = 0.7
            }
        }
    }
}
