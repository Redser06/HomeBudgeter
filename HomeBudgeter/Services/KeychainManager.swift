//
//  KeychainManager.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import Security

// MARK: - KeychainError

enum KeychainError: LocalizedError {
    case duplicateEntry
    case itemNotFound
    case encodingFailed
    case unknown(OSStatus)

    var errorDescription: String? {
        switch self {
        case .duplicateEntry:
            return "A keychain item with this key already exists."
        case .itemNotFound:
            return "The requested keychain item was not found."
        case .encodingFailed:
            return "Failed to encode the value for keychain storage."
        case .unknown(let status):
            return "Keychain operation failed with status: \(status)."
        }
    }
}

// MARK: - KeychainManager

final class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    enum KeychainKey: String {
        case apiKey              = "com.homebudgeter.apiKey"
        case encryptionSalt      = "com.homebudgeter.encryptionSalt"
        case claudeApiKey        = "com.homebudgeter.claudeApiKey"
        case geminiApiKey        = "com.homebudgeter.geminiApiKey"
        case supabaseAccessToken = "com.homebudgeter.supabaseAccessToken"
        case supabaseRefreshToken = "com.homebudgeter.supabaseRefreshToken"
    }

    // MARK: - Store

    func store(key: KeychainKey, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrAccount:    key.rawValue,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            throw KeychainError.duplicateEntry
        default:
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Retrieve

    func retrieve(key: KeychainKey) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    // MARK: - Update

    func update(key: KeychainKey, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue
        ]

        let attributes: [CFString: Any] = [
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Delete

    func delete(key: KeychainKey) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Upsert

    func upsert(key: KeychainKey, value: String) throws {
        do {
            try store(key: key, value: value)
        } catch KeychainError.duplicateEntry {
            try update(key: key, value: value)
        }
    }
}
