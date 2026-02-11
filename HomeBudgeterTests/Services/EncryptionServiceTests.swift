//
//  EncryptionServiceTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import CryptoKit
@testable import Home_Budgeter

final class EncryptionServiceTests: XCTestCase {

    var sut: FileEncryptionService!

    override func setUp() {
        super.setUp()
        sut = FileEncryptionService.shared
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Key Management

    func test_getOrCreateEncryptionKey_returnsKey() throws {
        // When
        let key = try sut.getOrCreateEncryptionKey()

        // Then — SymmetricKey has no public equality; just verify it doesn't throw
        _ = key
    }

    func test_getOrCreateEncryptionKey_returnsSameKeyTwice() throws {
        // When
        let key1 = try sut.getOrCreateEncryptionKey()
        let key2 = try sut.getOrCreateEncryptionKey()

        // Then — both keys should produce identical encrypted output for the same nonce
        let testData = Data("consistency check".utf8)
        let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 12))
        let sealed1 = try AES.GCM.seal(testData, using: key1, nonce: nonce)
        let sealed2 = try AES.GCM.seal(testData, using: key2, nonce: nonce)
        XCTAssertEqual(sealed1.ciphertext, sealed2.ciphertext)
    }

    // MARK: - Encrypt / Decrypt Round-Trip

    func test_encryptDecrypt_roundTrip_preservesData() throws {
        // Given
        let originalData = Data("Hello, Home Budgeter!".utf8)

        // When
        let encrypted = try sut.encrypt(data: originalData)
        let decrypted = try sut.decrypt(data: encrypted)

        // Then
        XCTAssertEqual(decrypted, originalData)
    }

    func test_encryptDecrypt_withEmptyData_works() throws {
        // Given
        let emptyData = Data()

        // When
        let encrypted = try sut.encrypt(data: emptyData)
        let decrypted = try sut.decrypt(data: encrypted)

        // Then
        XCTAssertEqual(decrypted, emptyData)
    }

    func test_encryptDecrypt_withLargeData_works() throws {
        // Given — 1 MB of random-ish data
        let largeData = Data(repeating: 0xAB, count: 1_048_576)

        // When
        let encrypted = try sut.encrypt(data: largeData)
        let decrypted = try sut.decrypt(data: encrypted)

        // Then
        XCTAssertEqual(decrypted, largeData)
    }

    func test_encrypt_producesDataLargerThanInput() throws {
        // AES-GCM adds nonce (12 bytes) + tag (16 bytes)
        // Given
        let data = Data("test".utf8)

        // When
        let encrypted = try sut.encrypt(data: data)

        // Then
        XCTAssertGreaterThan(encrypted.count, data.count)
    }

    func test_encrypt_producesDifferentOutputEachTime() throws {
        // AES-GCM uses a random nonce, so each encryption should differ
        // Given
        let data = Data("same input".utf8)

        // When
        let encrypted1 = try sut.encrypt(data: data)
        let encrypted2 = try sut.encrypt(data: data)

        // Then
        XCTAssertNotEqual(encrypted1, encrypted2)
    }

    // MARK: - Decrypt Failure

    func test_decrypt_withCorruptedData_throws() {
        // Given
        let corruptedData = Data("this is not encrypted data".utf8)

        // Then
        XCTAssertThrowsError(try sut.decrypt(data: corruptedData)) { error in
            XCTAssertTrue(error is EncryptionError)
        }
    }

    func test_decrypt_withTruncatedData_throws() throws {
        // Given
        let data = Data("test".utf8)
        let encrypted = try sut.encrypt(data: data)
        let truncated = encrypted.prefix(encrypted.count / 2)

        // Then
        XCTAssertThrowsError(try sut.decrypt(data: Data(truncated))) { error in
            XCTAssertTrue(error is EncryptionError)
        }
    }

    // MARK: - File Encrypt / Decrypt

    func test_encryptFile_andDecryptFile_roundTrip() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let originalURL = tempDir.appendingPathComponent("test_encrypt_\(UUID().uuidString).txt")
        let originalContent = Data("Financial data: €1,234.56".utf8)
        try originalContent.write(to: originalURL)

        defer {
            try? FileManager.default.removeItem(at: originalURL)
        }

        // When
        let encryptedURL = try sut.encryptFile(at: originalURL)
        defer {
            try? FileManager.default.removeItem(at: encryptedURL)
        }

        let decryptedData = try sut.decryptFile(at: encryptedURL)

        // Then
        XCTAssertEqual(decryptedData, originalContent)
        XCTAssertTrue(encryptedURL.lastPathComponent.contains(".encrypted"))
    }

    func test_encryptFile_withNonexistentFile_throws() {
        // Given
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/file.txt")

        // Then
        XCTAssertThrowsError(try sut.encryptFile(at: fakeURL)) { error in
            XCTAssertTrue(error is EncryptionError)
        }
    }

    func test_decryptFile_withNonexistentFile_throws() {
        // Given
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/file.encrypted")

        // Then
        XCTAssertThrowsError(try sut.decryptFile(at: fakeURL)) { error in
            XCTAssertTrue(error is EncryptionError)
        }
    }

    // MARK: - Secure Documents Directory

    func test_getSecureDocumentsDirectory_returnsValidPath() {
        // When
        let dir = sut.getSecureDocumentsDirectory()

        // Then
        XCTAssertTrue(dir.path.contains("HomeBudgeter"))
        XCTAssertTrue(dir.path.contains("Documents"))
    }

    func test_getSecureDocumentsDirectory_createsDirectoryIfNeeded() {
        // When
        let dir = sut.getSecureDocumentsDirectory()

        // Then
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDir.boolValue)
    }
}
