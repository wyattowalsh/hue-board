import Foundation
import HueBoardKit
import Security

@MainActor
struct KeychainVault {
    private let service = "com.wyattowalsh.HueBoard"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func credential(bridgeID: String) throws -> HueBridgeCredential? {
        guard let data = try data(account: account(bridgeID: bridgeID)) else { return nil }
        return try decoder.decode(HueBridgeCredential.self, from: data)
    }

    func save(_ credential: HueBridgeCredential) throws {
        try set(try encoder.encode(credential), account: account(bridgeID: credential.bridgeID))
    }

    func removeCredential(bridgeID: String) throws {
        let query = baseQuery(account: account(bridgeID: bridgeID))
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainVaultError.status(status)
        }
    }

    private func account(bridgeID: String) -> String {
        "bridge.\(bridgeID.lowercased()).credential"
    }

    private func data(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainVaultError.status(status)
        }
        return data
    }

    private func set(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainVaultError.status(status) }
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add = SecItemAdd(insert as CFDictionary, nil)
        guard add == errSecSuccess else { throw KeychainVaultError.status(add) }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum KeychainVaultError: Error, LocalizedError {
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .status(let status): "Keychain operation failed (\(status))."
        }
    }
}
