import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var session: GameSession

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(LevelID.allCases, id: \.rawValue) { level in
                    NavigationLink(value: AppRoute.play(level)) {
                        LevelRow(level: level, save: session.save)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Levels")
    }
}

private struct LevelRow: View {
    let level: LevelID
    let save: GameSave

    var unlocked: Bool {
        // Linear unlock: must have at least reached this level in past plays.
        let order: [LevelID] = LevelID.allCases
        guard let here = order.firstIndex(of: level),
              let farthest = LevelID(rawValue: save.farthestLevel),
              let farIdx = order.firstIndex(of: farthest)
        else { return level == .world1_1 }
        return here <= farIdx
    }

    var best: Int { save.bestPerLevel[level.rawValue] ?? 0 }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(unlocked ? Color.orange.opacity(0.25) : Color.gray.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(level.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(unlocked ? .orange : .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(level.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(unlocked ? .primary : .secondary)
                if best > 0 {
                    Text("Best \(best)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !unlocked {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .opacity(unlocked ? 1 : 0.6)
        .allowsHitTesting(unlocked)
    }
}
