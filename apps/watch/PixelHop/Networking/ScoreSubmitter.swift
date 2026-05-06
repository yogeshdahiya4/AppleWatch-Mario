import Foundation

/// Pending submission persisted to disk while we're offline.
struct PendingScore: Codable, Equatable, Identifiable {
    var id: UUID
    var submission: APIClient.ScoreSubmission
    var queuedAt: Date
}

/// Submits scores; on offline / 5xx, stashes them in a JSON file and tries again on next launch.
@MainActor
final class ScoreSubmitter {
    private let api: APIClient
    private let queueURL: URL

    init(api: APIClient) {
        self.api = api
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.queueURL = docs.appendingPathComponent("pending-scores.json")
    }

    func submit(_ submission: APIClient.ScoreSubmission, identity: DeviceIdentity) async {
        do {
            _ = try await api.submitScore(submission, identity: identity)
        } catch APIError.offline {
            queue(submission)
        } catch APIError.server(let status, _) where (500...599).contains(status) {
            queue(submission)
        } catch {
            // Authorization or 4xx — drop, no point retrying with same payload.
        }
    }

    func flushPending(identity: DeviceIdentity) async {
        var pending = loadQueue()
        guard !pending.isEmpty else { return }
        var remaining: [PendingScore] = []
        for p in pending {
            do {
                _ = try await api.submitScore(p.submission, identity: identity)
            } catch APIError.offline, APIError.server {
                remaining.append(p)
            } catch {
                // drop on auth errors
            }
        }
        pending = remaining
        saveQueue(pending)
    }

    private func queue(_ s: APIClient.ScoreSubmission) {
        var q = loadQueue()
        q.append(PendingScore(id: UUID(), submission: s, queuedAt: Date()))
        saveQueue(q)
    }

    private func loadQueue() -> [PendingScore] {
        guard let data = try? Data(contentsOf: queueURL),
              let decoded = try? JSONDecoder().decode([PendingScore].self, from: data)
        else { return [] }
        return decoded
    }

    private func saveQueue(_ q: [PendingScore]) {
        guard let data = try? JSONEncoder().encode(q) else { return }
        try? data.write(to: queueURL, options: .atomic)
    }
}
