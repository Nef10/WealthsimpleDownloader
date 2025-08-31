//
//  TokenTests.swift
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

// MARK: - Mock Classes

class MockCredentialStorage: CredentialStorage {
    var storage: [String: String] = [:]

    func save(_ value: String, for key: String) {
        storage[key] = value
    }

    func read(_ key: String) -> String? {
        storage[key]
    }
}

final class TokenTests: XCTestCase {

    private var mockCredentialStorage: MockCredentialStorage!
    private let mockBaseURL = "https://mock.wealthsimple.test/v1/"

    override func setUp() {
        super.setUp()
        mockCredentialStorage = MockCredentialStorage()
        URLConfiguration.shared.setBaseURL(mockBaseURL)
    }

    override func tearDown() {
        super.tearDown()
        URLConfiguration.shared.setBaseURL("https://api.production.wealthsimple.com/v1/")
        mockCredentialStorage = nil
    }

    // MARK: - TokenError Tests

    func testTokenErrorCases() {
        let noTokenError = TokenError.noToken
        let invalidJsonError = TokenError.invalidJson(error: "test error")
        let invalidJsonTypeError = TokenError.invalidJsonType(json: ["invalid": "type"])
        let invalidParametersError = TokenError.invalidParameters(parameters: ["param": "value"])
        let missingResultParameterError = TokenError.missingResultParamenter(json: ["missing": "param"])
        let httpError = TokenError.httpError(error: "HTTP error")
        let noDataReceivedError = TokenError.noDataReceived

        XCTAssertNotNil(noTokenError)
        XCTAssertNotNil(invalidJsonError)
        XCTAssertNotNil(invalidJsonTypeError)
        XCTAssertNotNil(invalidParametersError)
        XCTAssertNotNil(missingResultParameterError)
        XCTAssertNotNil(httpError)
        XCTAssertNotNil(noDataReceivedError)
    }

    // MARK: - URL Configuration Tests

    func testTokenURLsUseConfiguration() {
        let originalURL = URLConfiguration.shared.base

        URLConfiguration.shared.setBaseURL("https://custom.api.test/v2/")

        XCTAssertEqual(URLConfiguration.shared.url(for: "oauth/token"), "https://custom.api.test/v2/oauth/token")
        XCTAssertEqual(URLConfiguration.shared.url(for: "oauth/token/info"), "https://custom.api.test/v2/oauth/token/info")

        URLConfiguration.shared.setBaseURL(originalURL)
    }

    // MARK: - getToken from CredentialStorage Tests

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

    // MARK: - Token Creation Network Tests

    func testGetTokenWithUsernamePasswordOTPNetworkFailure() {
        let expectation = XCTestExpectation(description: "getToken completion")

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to mock URL")
            case .failure(let error):
                XCTAssertNotNil(error)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
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

    // MARK: - Date and Expiry Logic Tests

    func testExpiryCalculation() {
        let expiredTimestamp = Date().addingTimeInterval(-3_600).timeIntervalSince1970
        let futureTimestamp = Date().addingTimeInterval(3_600).timeIntervalSince1970

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(expiredTimestamp)

        let expiredExpectation = XCTestExpectation(description: "expired token test")

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            expiredExpectation.fulfill()
        }

        wait(for: [expiredExpectation], timeout: 10.0)

        mockCredentialStorage.storage["expiry"] = String(futureTimestamp)

        let futureExpectation = XCTestExpectation(description: "future token test")

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            futureExpectation.fulfill()
        }

        wait(for: [futureExpectation], timeout: 10.0)
    }

    // MARK: - Edge Case Tests

    func testTokenWithExtremeTimestamps() {
        let veryOldDate = Date(timeIntervalSince1970: 0)
        let veryFutureDate = Date(timeIntervalSince1970: 2_147_483_647)

        mockCredentialStorage.storage["accessToken"] = "old_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(veryOldDate.timeIntervalSince1970)

        let oldExpectation = XCTestExpectation(description: "very old token")
        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            oldExpectation.fulfill()
        }

        mockCredentialStorage.storage["expiry"] = String(veryFutureDate.timeIntervalSince1970)

        let futureExpectation = XCTestExpectation(description: "very future token")
        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            futureExpectation.fulfill()
        }

        wait(for: [oldExpectation, futureExpectation], timeout: 15.0)
    }

    // MARK: - CredentialStorage Comprehensive Tests

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

    // MARK: - Token Request Parameter Tests

    func testTokenRequestParameters() {
        let testCases = [
            ("", "", ""),
            ("user", "", ""),
            ("", "pass", ""),
            ("", "", "123456"),
            ("user", "pass", ""),
            ("user", "", "123456"),
            ("", "pass", "123456"),
            ("a@b.c", "password", "123456")
        ]

        let expectations = testCases.indices.map { index in
            XCTestExpectation(description: "Test case \(index)")
        }

        for (index, testCase) in testCases.enumerated() {
            Token.getToken(
                username: testCase.0,
                password: testCase.1,
                otp: testCase.2,
                credentialStorage: mockCredentialStorage
            ) { result in
                if case .failure = result {
                    expectations[index].fulfill()
                } else {
                    XCTFail("Expected failure for test case \(index)")
                }
            }
        }

        wait(for: expectations, timeout: 20.0)
    }

    // MARK: - Multiple Concurrent Token Requests

    func testConcurrentTokenRequests() {
        let numberOfRequests = 5
        let expectations = (0..<numberOfRequests).map { XCTestExpectation(description: "Request \($0)") }

        for requestIndex in 0..<numberOfRequests {
            Token.getToken(
                username: "user\(requestIndex)@test.com",
                password: "password\(requestIndex)",
                otp: "12345\(requestIndex)",
                credentialStorage: mockCredentialStorage
            ) { result in
                if case .failure = result {
                    expectations[requestIndex].fulfill()
                } else {
                    XCTFail("Expected failure for request \(requestIndex)")
                }
            }
        }

        wait(for: expectations, timeout: 30.0)
    }

    // MARK: - Token Static Configuration Tests

    func testTokenStaticConfiguration() {
        let config = URLConfiguration.shared

        let tokenURL = config.urlObject(for: "oauth/token")
        XCTAssertNotNil(tokenURL)
        XCTAssertTrue(tokenURL!.absoluteString.contains("oauth/token"))

        let infoURL = config.urlObject(for: "oauth/token/info")
        XCTAssertNotNil(infoURL)
        XCTAssertTrue(infoURL!.absoluteString.contains("oauth/token/info"))

        XCTAssertNotEqual(tokenURL, infoURL)
    }
}
