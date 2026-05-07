import Foundation
import Security

/// Stable per-device identity. Stored in `UserDefaults` (the sim/watch keychain
/// requires an Access-Group entitlement that's hard to set up with free
/// signing — and the secret isn't catastrophic to leak: it only authenticates
/// score submissions for one device id).
///
/// We additionally write a copy to the Keychain when possible. UserDefaults is
/// the source of truth; Keychain is a best-effort secondary.
struct DeviceIdentity: Equatable, Sendable {
    let id: UUID
    let nickname: String
    let secret: String   // hex-encoded HMAC key

    static let storageKey = "pixelhop.device-identity.v1"
    static let keychainService = "com.yogeshdahiya.pixelhop"
    static let keychainAccount = "device-identity"

    static func registerNew(nickname: String, api: APIClient) async throws -> DeviceIdentity {
        let id = UUID()
        let response = try await api.registerDevice(deviceId: id, nickname: nickname)
        return DeviceIdentity(id: id, nickname: response.nickname, secret: response.secret)
    }

    /// Save to UserDefaults; *also* try the Keychain (best-effort, doesn't error).
    func persistToKeychain() throws {
        let payload = try JSONEncoder().encode(StoredPayload(id: id, nickname: nickname, secret: secret))
        UserDefaults.standard.set(payload, forKey: Self.storageKey)
        UserDefaults.standard.synchronize()
        // Best-effort Keychain write — silently fails on sandboxed sim/free-tier device
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = payload
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(add as CFDictionary, nil)
    }

    static func loadFromKeychain() -> DeviceIdentity? {
        // Primary: UserDefaults
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let payload = try? JSONDecoder().decode(StoredPayload.self, from: data) {
            return DeviceIdentity(id: payload.id, nickname: payload.nickname, secret: payload.secret)
        }
        // Fallback: Keychain
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let payload = try? JSONDecoder().decode(StoredPayload.self, from: data)
        else { return nil }
        return DeviceIdentity(id: payload.id, nickname: payload.nickname, secret: payload.secret)
    }

    fileprivate struct StoredPayload: Codable {
        let id: UUID
        let nickname: String
        let secret: String
    }
}

enum DeviceIdentityError: LocalizedError {
    case keychainError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain status \(status)"
        }
    }
}
