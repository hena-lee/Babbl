import Foundation
import CryptoKit
import Security
import os.log

/// Encrypts/decrypts transcription history using a symmetric key stored in the macOS Keychain.
enum HistoryCrypto {
    private static let logger = Logger(subsystem: "com.babbl.app", category: "HistoryCrypto")
    private static let keychainService = "com.babbl.app.history"
    private static let keychainAccount = "encryption-key"

    static func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    static func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Keychain

    private static func getOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKeyFromKeychain() {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey)
        Self.logger.info("Created new encryption key in Keychain")
        return newKey
    }

    private static func loadKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data else { return nil }
            return SymmetricKey(data: keyData)
        case errSecItemNotFound:
            return nil
        default:
            throw CryptoError.keychainError(status)
        }
    }

    private static func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CryptoError.keychainError(status)
        }
    }

    enum CryptoError: LocalizedError {
        case encryptionFailed
        case keychainError(OSStatus)

        var errorDescription: String? {
            switch self {
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .keychainError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
}
