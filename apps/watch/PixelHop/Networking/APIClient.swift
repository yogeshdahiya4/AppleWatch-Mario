import Foundation

enum APIError: Error, Equatable {
    case offline
    case server(status: Int, body: String)
    case conflict
    case decoding(String)
    case unauthorized
}

/// Async/await wrapper around URLSession for the PixelHop API.
/// Designed for slow/spotty watch networking: 8s timeout, single retry on 5xx.
actor APIClient {
    let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "https://applewatch-mario-api.72.62.0.34.sslip.io")!,
        session: URLSession = {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 8
            cfg.timeoutIntervalForResource = 16
            cfg.waitsForConnectivity = true
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            return URLSession(configuration: cfg)
        }()
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Endpoints

    struct DeviceRegistrationResponse: Decodable {
        let device_id: String
        let nickname: String
        let secret: String
    }

    func registerDevice(deviceId: UUID, nickname: String) async throws -> DeviceRegistrationResponse {
        let body = try JSONEncoder().encode([
            "device_id": deviceId.uuidString.lowercased(),
            "nickname": nickname,
        ])
        let request = URLRequest.json(method: "POST", url: baseURL.appending(path: "/v1/devices"), body: body)
        let (data, http) = try await send(request)
        switch http.statusCode {
        case 201:
            return try JSONDecoder().decode(DeviceRegistrationResponse.self, from: data)
        case 409:
            throw APIError.conflict
        default:
            throw APIError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
    }

    struct ScoreSubmission: Codable, Equatable {
        let level: String
        let score: Int
        let time_ms: Int
        let coins: Int
        let world_completed: Bool
    }

    struct ScoreSubmissionResponse: Decodable {
        let id: Int
        let nickname: String
    }

    func submitScore(_ submission: ScoreSubmission, identity: DeviceIdentity) async throws -> ScoreSubmissionResponse {
        let body = try JSONEncoder().encode(submission)
        let bodyString = String(data: body, encoding: .utf8) ?? ""
        let path = "/v1/scores"
        let signer = HMACSigner(secret: identity.secret)
        let signed = signer.sign(method: "POST", path: path, body: bodyString)

        var request = URLRequest.json(method: "POST", url: baseURL.appending(path: path), body: body)
        request.setValue(identity.id.uuidString.lowercased(), forHTTPHeaderField: "X-Device-Id")
        request.setValue(String(signed.timestamp), forHTTPHeaderField: "X-Timestamp")
        request.setValue(signed.nonce, forHTTPHeaderField: "X-Nonce")
        request.setValue(signed.signature, forHTTPHeaderField: "X-Sig")

        let (data, http) = try await send(request)
        switch http.statusCode {
        case 201:
            return try JSONDecoder().decode(ScoreSubmissionResponse.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
    }

    struct LeaderboardEntry: Decodable, Hashable, Identifiable {
        let device_id: String
        let nickname: String
        let score: Int
        let time_ms: Int
        let coins: Int?
        let rank: Int?
        var id: String { device_id }
    }

    struct LeaderboardResponse: Decodable {
        let level: String?
        let scope: String?
        let top: [LeaderboardEntry]
        let me: LeaderboardEntry?
    }

    func leaderboard(level: String, deviceId: UUID? = nil) async throws -> LeaderboardResponse {
        var url = baseURL.appending(path: "/v1/leaderboard/\(level)")
        if let deviceId {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "device", value: deviceId.uuidString.lowercased())]
            url = comps.url!
        }
        let (data, http) = try await send(URLRequest(url: url))
        guard http.statusCode == 200 else {
            throw APIError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(LeaderboardResponse.self, from: data)
    }

    func globalLeaderboard() async throws -> LeaderboardResponse {
        let (data, http) = try await send(URLRequest(url: baseURL.appending(path: "/v1/leaderboard")))
        guard http.statusCode == 200 else {
            throw APIError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(LeaderboardResponse.self, from: data)
    }

    // MARK: - send w/ retry

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.server(status: 0, body: "no http response")
            }
            // Single retry on 5xx
            if (500...599).contains(http.statusCode) {
                try? await Task.sleep(nanoseconds: 600_000_000)
                let (data2, response2) = try await session.data(for: request)
                guard let http2 = response2 as? HTTPURLResponse else {
                    throw APIError.server(status: 0, body: "no http response")
                }
                return (data2, http2)
            }
            return (data, http)
        } catch {
            if let urlErr = error as? URLError, [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlErr.code) {
                throw APIError.offline
            }
            throw error
        }
    }
}

private extension URLRequest {
    static func json(method: String, url: URL, body: Data? = nil) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("PixelHop/1.0 watchOS", forHTTPHeaderField: "User-Agent")
        r.httpBody = body
        return r
    }
}

extension URL {
    fileprivate func appending(path: String) -> URL {
        appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }
}
