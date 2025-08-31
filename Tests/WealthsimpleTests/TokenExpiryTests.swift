//
//  TokenExpiryTests.swift
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

/// Tests for Token expiry calculation and edge cases with timestamps.
final class TokenExpiryTests: XCTestCase {

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

    // MARK: - Date and Expiry Logic Tests

    func testExpiryCalculation() {
        setupMockForExpiredTokens()
        runExpiredTokenTest()
        runFutureTokenTest()
        restoreDefaultMockHandler()
    }

    private func setupMockForExpiredTokens() {
        // Test with mock that simulates server rejection for expired tokens
        MockURLProtocol.requestHandler = { request in
            try self.handleExpiredTokenMockRequest(request)
        }
    }

    private func handleExpiredTokenMockRequest(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let data = Data()
        let statusCode: Int

        if url.path.contains("/oauth/token") && request.httpMethod == "POST" {
            statusCode = 401 // Simulate server rejecting refresh token requests for expired tokens
        } else if url.path.contains("/oauth/token/info") {
            statusCode = 401 // Simulate server rejecting token validation
        } else {
            statusCode = 404
        }

        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private func runExpiredTokenTest() {
        let expiredTimestamp = Date().addingTimeInterval(-3_600).timeIntervalSince1970

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(expiredTimestamp)

        let expiredExpectation = XCTestExpectation(description: "expired token test")

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            expiredExpectation.fulfill()
        }

        wait(for: [expiredExpectation], timeout: 10.0)
    }

    private func runFutureTokenTest() {
        let futureTimestamp = Date().addingTimeInterval(3_600).timeIntervalSince1970
        mockCredentialStorage.storage["expiry"] = String(futureTimestamp)

        let futureExpectation = XCTestExpectation(description: "future token test")

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            futureExpectation.fulfill()
        }

        wait(for: [futureExpectation], timeout: 10.0)
    }

    private func restoreDefaultMockHandler() {
        // Restore default handler
        MockURLProtocol.requestHandler = { request in
            try MockURLProtocol.handleMockRequest(request)
        }
    }

    // MARK: - Edge Case Tests

    func testTokenWithExtremeTimestamps() {
        setupMockToRejectTokenRequests()
        runVeryOldTokenTest()
        runVeryFutureTokenTest()
        restoreDefaultMockHandler()
    }

    private func setupMockToRejectTokenRequests() {
        // Set up mock to reject token refresh/validation requests
        MockURLProtocol.requestHandler = { request in
            try self.handleRejectTokenMockRequest(request)
        }
    }

    private func handleRejectTokenMockRequest(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let data = Data()
        let statusCode: Int

        if url.path.contains("/oauth/token") || url.path.contains("/oauth/token/info") {
            statusCode = 401 // Simulate server rejection for extreme timestamps
        } else {
            statusCode = 404
        }

        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private func runVeryOldTokenTest() {
        let veryOldDate = Date(timeIntervalSince1970: 0)

        mockCredentialStorage.storage["accessToken"] = "old_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(veryOldDate.timeIntervalSince1970)

        let oldExpectation = XCTestExpectation(description: "very old token")
        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            oldExpectation.fulfill()
        }

        wait(for: [oldExpectation], timeout: 15.0)
    }

    private func runVeryFutureTokenTest() {
        let veryFutureDate = Date(timeIntervalSince1970: 2_147_483_647)
        mockCredentialStorage.storage["expiry"] = String(veryFutureDate.timeIntervalSince1970)

        let futureExpectation = XCTestExpectation(description: "very future token")
        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            futureExpectation.fulfill()
        }

        wait(for: [futureExpectation], timeout: 15.0)
    }
}
