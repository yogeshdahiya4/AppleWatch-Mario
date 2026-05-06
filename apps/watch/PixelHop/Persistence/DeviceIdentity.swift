import Foundation
import Security

/// Stable per-device identity stored in the watch's Keychain.
/// Lifecycle: generated on first launch, persists until app/device wipe.
struct DeviceIdentity: Equatable, Sendable {
    let id: UUID
    let nickname: String
    let secret: String   // hex-encoded HMAC key

    static let keychainService = "com.yogeshdahiya.pixelhop"
    static let keychainAccount = "device-identity"

    /// Try to register a new identity with the backend.
    /// Returns the new local identity if the server accepts.
    static func registerNew(nickname: String, api: APIClient) async throws -> DeviceIdentity {
        let id = UUID()
        let response = try await api.registerDevice(deviceId: id, nickname: nickname)
        return DeviceIdentity(id: id, nickname: response.nickname, secret: response.secret)
    }

    func persistToKeychain() throws {
        let payload = try JSONEncoder().encode(KeychainPayload(id: id, nickname: nickname, secret: secret))
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = payload
        // Limit to this device — keychain syncing across devices is wrong here.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw DeviceIdentityError.keychainError(status: status) }
    }

    static func loadFromKeychain() -> DeviceIdentity? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        guard let payload = try? JSONDecoder().decode(KeychainPayload.self, from: data) else { return nil }
        return DeviceIdentity(id: payload.id, nickname: payload.nickname, secret: payload.secret)
    }

    fileprivate struct KeychainPayload: Codable {
        let id: UUID
        let nickname: String
        let secret: String
    }
}

enum DeviceIdentityError: Error {
    case keychainError(status: OSStatus)
}
