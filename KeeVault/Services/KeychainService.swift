import Foundation
import Security
import LocalAuthentication

enum KeychainService {
    private static let service = "com.keevault.app"
    private static let compositeKeyAccount = "compositeKey"

    /// Use filename only — bookmark-resolved paths can change between launches
    private static func accountKey(for databasePath: String) -> String {
        let filename = URL(fileURLWithPath: databasePath).lastPathComponent
        return "\(compositeKeyAccount):\(filename)"
    }

    static func storeCompositeKey(_ key: Data, for databasePath: String) throws {
        let account = accountKey(for: databasePath)

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Create access control requiring biometric authentication
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw KeychainError.accessControlFailed
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key,
            kSecAttrAccessControl as String: accessControl,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    static func retrieveCompositeKey(for databasePath: String, context: LAContext) throws -> Data {
        let account = accountKey(for: databasePath)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.retrieveFailed(status)
        }
        return data
    }

    static func deleteCompositeKey(for databasePath: String) {
        let account = accountKey(for: databasePath)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hasStoredKey(for databasePath: String) -> Bool {
        let account = accountKey(for: databasePath)
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationContext as String: context,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // Item exists if we get success, or if auth is needed (interaction not allowed / auth failed)
        let exists = status == errSecSuccess || status == errSecInteractionNotAllowed || status == errSecAuthFailed
        if !exists && status != errSecItemNotFound {
            print("[KeychainService] hasStoredKey unexpected status: \(status)")
        }
        return exists
    }

    enum KeychainError: Error, LocalizedError {
        case accessControlFailed
        case storeFailed(OSStatus)
        case retrieveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .accessControlFailed: "Failed to create biometric access control"
            case .storeFailed(let s): "Keychain store failed (status \(s))"
            case .retrieveFailed(let s): "Keychain retrieve failed (status \(s))"
            }
        }
    }
}
