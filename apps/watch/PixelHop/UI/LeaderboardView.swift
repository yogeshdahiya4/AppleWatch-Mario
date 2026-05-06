import SwiftUI

struct LeaderboardView: View {
    let scope: LeaderboardScope
    @EnvironmentObject private var session: GameSession
    @State private var rows: [APIClient.LeaderboardEntry] = []
    @State private var me: APIClient.LeaderboardEntry?
    @State private var loadState: LoadState = .loading

    enum LoadState { case loading, ok, error(String) }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                switch loadState {
                case .loading:
                    ProgressView().padding(.top, 24)
                case .error(let msg):
                    VStack(spacing: 6) {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.bordered)
                    }
                    .padding(.top, 12)
                case .ok:
                    if let me {
                        Section {
                            EntryRow(entry: me, isMe: true)
                        } header: {
                            sectionHeader("YOUR RANK")
                        }
                    }
                    Section {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            EntryRow(entry: row, isMe: row.device_id == session.deviceIdentity?.id.uuidString.lowercased(),
                                       fallbackRank: idx + 1)
                        }
                    } header: {
                        sectionHeader(scope == .global ? "TOP 100 — GLOBAL" : "TOP 100")
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle({
            switch scope {
            case .global: return "Global"
            case .level(let l): return l.displayName
            }
        }())
        .task { await load() }
        .refreshable { await load() }
    }

    private func sectionHeader(_ s: String) -> some View {
        HStack {
            Text(s)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 6)
    }

    @MainActor
    private func load() async {
        loadState = .loading
        do {
            switch scope {
            case .level(let l):
                let resp = try await session.api.leaderboard(
                    level: l.rawValue,
                    deviceId: session.deviceIdentity?.id
                )
                rows = resp.top
                me = resp.me
            case .global:
                let resp = try await session.api.globalLeaderboard()
                rows = resp.top
                me = nil
            }
            loadState = .ok
        } catch APIError.offline {
            loadState = .error("You're offline. Pull down to retry.")
        } catch {
            loadState = .error("Couldn't load: \(error.localizedDescription)")
        }
    }
}

private struct EntryRow: View {
    let entry: APIClient.LeaderboardEntry
    var isMe: Bool = false
    var fallbackRank: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text("#\(entry.rank ?? fallbackRank ?? 0)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: 26, alignment: .leading)
                .foregroundStyle(isMe ? .yellow : .secondary)
            Text(entry.nickname)
                .font(.system(size: 12, weight: isMe ? .bold : .semibold))
                .foregroundStyle(isMe ? .yellow : .primary)
                .lineLimit(1)
            Spacer()
            Text("\(entry.score)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isMe ? .yellow.opacity(0.18) : .white.opacity(0.04))
        )
    }
}
