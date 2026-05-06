import SwiftUI

struct GameOverView: View {
    let result: GameRunResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "xmark.octagon.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundStyle(.red)
            Text("Game Over")
                .font(.system(size: 20, weight: .black, design: .rounded))
            Text("Score \(result.score)")
                .font(.caption).foregroundStyle(.secondary)
            Button("Try again") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct WorldCompleteView: View {
    let result: GameRunResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundStyle(.yellow)
            Text("World Complete!")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Score \(result.score)").font(.caption)
            Text("Coins \(result.coins) • Time \(result.timeMs / 1000)s").font(.caption2).foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
        }
    }
}
