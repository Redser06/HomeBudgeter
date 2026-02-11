//
//  FileEncryptionService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import CryptoKit

// MARK: - EncryptionError

enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    case fileNotFound
    case dataReadFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt the file."
        case .decryptionFailed:
            return "Failed to decrypt the file. The key may be incorrect."
        case .keyGenerationFailed:
            return "Failed to generate encryption key."
        case .fileNotFound:
            return "The specified file was not found."
        case .dataReadFailed:
            return "Failed to read file data."
        }
    }
}

// MARK: - FileEncryptionService

final class FileEncryptionService {
    static let shared = FileEncryptionService()

    private let keychain = KeychainManager.shared
    private let encryptionKeyTag = KeychainManager.KeychainKey.encryptionSalt

    private init() {}

    // MARK: - Key Management

    /// Returns the app's encryption key, creating one if it doesn't exist.
    func getOrCreateEncryptionKey() throws -> SymmetricKey {
        if let existingSalt = keychain.retrieve(key: encryptionKeyTag) {
            guard let keyData = Data(base64Encoded: existingSalt) else {
                throw EncryptionError.keyGenerationFailed
            }
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let base64Key = keyData.base64EncodedString()

        try keychain.upsert(key: encryptionKeyTag, value: base64Key)
        return key
    }

    // MARK: - Encrypt

    /// Encrypts data using AES-GCM and returns the sealed box combined representation.
    func encrypt(data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            return combined
        } catch is EncryptionError {
            throw EncryptionError.encryptionFailed
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// Encrypts a file at the given URL and writes the encrypted version alongside it.
    /// Returns the URL of the encrypted file.
    func encryptFile(at url: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EncryptionError.fileNotFound
        }

        guard let data = try? Data(contentsOf: url) else {
            throw EncryptionError.dataReadFailed
        }

        let encryptedData = try encrypt(data: data)
        let encryptedURL = url.appendingPathExtension("encrypted")
        try encryptedData.write(to: encryptedURL)
        return encryptedURL
    }

    // MARK: - Decrypt

    /// Decrypts data that was encrypted with AES-GCM.
    func decrypt(data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// Decrypts a file at the given URL and returns the plaintext data.
    func decryptFile(at url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EncryptionError.fileNotFound
        }

        guard let data = try? Data(contentsOf: url) else {
            throw EncryptionError.dataReadFailed
        }

        return try decrypt(data: data)
    }

    // MARK: - Secure Documents Directory

    /// Returns the app's secure documents storage directory, creating it if needed.
    func getSecureDocumentsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let documentsDir = appSupport.appendingPathComponent("HomeBudgeter/Documents", isDirectory: true)

        if !FileManager.default.fileExists(atPath: documentsDir.path) {
            try? FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
        }

        return documentsDir
    }
}
