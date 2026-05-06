import CryptoKit
import Foundation

/// Signs requests for the leaderboard API.
/// Format must match `services/api/src/middleware/hmac.ts` exactly:
///   message = "${METHOD}\n${PATH}\n${TIMESTAMP}\n${NONCE}\n${BODY}"
///   sig     = hex(HMAC-SHA256(secret, message))
struct HMACSigner {
    let secret: String   // hex-encoded

    struct SignedRequest {
        let timestamp: Int
        let nonce: String
        let signature: String
    }

    func sign(method: String, path: String, body: String) -> SignedRequest {
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = randomHex(bytes: 16)
        let message = "\(method.uppercased())\n\(path)\n\(timestamp)\n\(nonce)\n\(body)"
        guard let key = secretKey, let messageData = message.data(using: .utf8) else {
            return SignedRequest(timestamp: timestamp, nonce: nonce, signature: "")
        }
        let mac = HMAC<SHA256>.authenticationCode(for: messageData, using: key)
        let hex = mac.map { String(format: "%02x", $0) }.joined()
        return SignedRequest(timestamp: timestamp, nonce: nonce, signature: hex)
    }

    private var secretKey: SymmetricKey? {
        guard let bytes = hexBytes(secret) else { return nil }
        return SymmetricKey(data: bytes)
    }

    private func hexBytes(_ hex: String) -> Data? {
        guard hex.count % 2 == 0 else { return nil }
        var data = Data(capacity: hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard let byte = UInt8(hex[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        return data
    }

    private func randomHex(bytes: Int) -> String {
        var buf = [UInt8](repeating: 0, count: bytes)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes, &buf)
        return buf.map { String(format: "%02x", $0) }.joined()
    }
}
