//
//  TokenCredentialStorageTests.swift
//
//
//  Created by Steffen Kötte on 2025-08-31.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Wealthsimple
import XCTest

/// Tests for Token credential storage functionality.
final class TokenCredentialStorageTests: XCTestCase {

    private let tokenTestBase = TokenTestBase()

    private var mockCredentialStorage: MockCredentialStorage! {
        tokenTestBase.mockCredentialStorage
    }

    override func setUp() {
        super.setUp()
        tokenTestBase.setUp()
    }

    override func tearDown() {
        super.tearDown()
        tokenTestBase.tearDown()
    }

    // MARK: - getToken from CredentialStorage Tests

    func testGetTokenFromCredentialStorageWithValidToken() {
        let expectation = XCTestExpectation(description: "getToken completion")

        // Set up valid token data in credential storage
        mockCredentialStorage.storage["accessToken"] = "mock_access_token_12345"
        mockCredentialStorage.storage["refreshToken"] = "mock_refresh_token_67890"
        let futureExpiry = Date().addingTimeInterval(3_600).timeIntervalSince1970
        mockCredentialStorage.storage["expiry"] = String(futureExpiry)

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNotNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetTokenFromCredentialStorageWithMissingAccessToken() {
        let expectation = XCTestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTokenFromCredentialStorageWithMissingRefreshToken() {
        let expectation = XCTestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTokenFromCredentialStorageWithMissingExpiry() {
        let expectation = XCTestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetTokenFromCredentialStorageWithInvalidExpiry() {
        let expectation = XCTestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"
        mockCredentialStorage.storage["expiry"] = "invalid_date"

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Credential Storage Tests

    func testCredentialStorageSaveAndRead() {
        let storage = MockCredentialStorage()

        storage.save("test_value", for: "test_key")
        XCTAssertEqual(storage.read("test_key"), "test_value")

        storage.save("another_value", for: "test_key")
        XCTAssertEqual(storage.read("test_key"), "another_value")

        XCTAssertNil(storage.read("nonexistent_key"))
    }

    func testCredentialStorageEdgeCases() {
        let storage = MockCredentialStorage()

        storage.save("", for: "empty")
        XCTAssertEqual(storage.read("empty"), "")

        storage.save("   ", for: "whitespace")
        XCTAssertEqual(storage.read("whitespace"), "   ")

        storage.save("!@#$%^&*()_+-=[]{}|;':\",./<>?", for: "special")
        XCTAssertEqual(storage.read("special"), "!@#$%^&*()_+-=[]{}|;':\",./<>?")

        storage.save("🔑🌟💰", for: "unicode")
        XCTAssertEqual(storage.read("unicode"), "🔑🌟💰")

        let longString = String(repeating: "a", count: 10_000)
        storage.save(longString, for: "long")
        XCTAssertEqual(storage.read("long"), longString)

        storage.save("first", for: "overwrite")
        storage.save("second", for: "overwrite")
        XCTAssertEqual(storage.read("overwrite"), "second")
    }
}
