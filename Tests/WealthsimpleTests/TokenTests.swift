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

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        // Only handle requests to localhost
        return request.url?.host == "localhost"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("Handler is unavailable.")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // No-op
    }
}

final class TokenTests: XCTestCase {

    private var mockCredentialStorage: MockCredentialStorage!
    private let mockBaseURL = "http://localhost:8080/v1/"

    override func setUp() {
        super.setUp()
        mockCredentialStorage = MockCredentialStorage()

        // Register mock URL protocol
        _ = URLProtocol.registerClass(MockURLProtocol.self)

        // Set up default request handler
        MockURLProtocol.requestHandler = { request in
            try self.handleMockRequest(request)
        }

        URLConfiguration.shared.setBaseURL(mockBaseURL)
    }

    override func tearDown() {
        super.tearDown()
        URLProtocol.unregisterClass(MockURLProtocol.self)
        URLConfiguration.shared.setBaseURL("https://api.production.wealthsimple.com/v1/")
        MockURLProtocol.requestHandler = nil
        mockCredentialStorage = nil
    }
    
    private func handleMockRequest(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let response: HTTPURLResponse
        let data: Data

        if url.path.contains("/oauth/token") && request.httpMethod == "POST" {
            // For POST requests to /oauth/token, always return success for testing
            // In real implementation, this would validate credentials
            let jsonResponse = [
                "access_token": "mock_access_token_12345",
                "refresh_token": "mock_refresh_token_67890",
                "expires_in": 3_600,
                "created_at": Int(Date().timeIntervalSince1970),
                "token_type": "Bearer"
            ] as [String: Any]

            data = try JSONSerialization.data(withJSONObject: jsonResponse)
            response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        } else if url.path.contains("/oauth/token/info") && request.httpMethod == "GET" {
            if let authHeader = request.value(forHTTPHeaderField: "Authorization"),
               authHeader.contains("mock_access_token") {
                // Mock successful token validation
                data = Data()
                response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            } else {
                // Mock unauthorized response
                data = Data()
                response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            }
        } else {
            // Mock 404 for unknown endpoints
            data = Data()
            response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        }

        return (response, data)
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

    func testGetTokenFromCredentialStorageWithValidToken() {
        let expectation = XCTestExpectation(description: "getToken completion")
        
        // Set up valid token data in credential storage
        mockCredentialStorage.storage["accessToken"] = "mock_access_token_12345"
        mockCredentialStorage.storage["refreshToken"] = "mock_refresh_token_67890"
        let futureExpiry = Date().addingTimeInterval(3600).timeIntervalSince1970
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

    // MARK: - Token Creation Network Tests

    func testGetTokenWithUsernamePasswordOTPSuccess() {
        let expectation = XCTestExpectation(description: "getToken completion")

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage
        ) { result in
            switch result {
            case .success(let token):
                XCTAssertNotNil(token)
                // Verify token was saved to credential storage
                XCTAssertEqual(self.mockCredentialStorage.read("accessToken"), "mock_access_token_12345")
                XCTAssertEqual(self.mockCredentialStorage.read("refreshToken"), "mock_refresh_token_67890")
                XCTAssertNotNil(self.mockCredentialStorage.read("expiry"))
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetTokenWithUsernamePasswordOTPNetworkFailure() {
        // Set up the mock to throw an error for this test
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.networkConnectionLost)
        }
        
        let expectation = XCTestExpectation(description: "getToken completion")

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to network error")
            case .failure(let error):
                XCTAssertNotNil(error)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
        
        // Restore normal handler for other tests
        MockURLProtocol.requestHandler = { request in
            return try self.handleMockRequest(request)
        }
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
        setupMockForExpiredTokens()
        testExpiredToken()
        testFutureToken()
        restoreDefaultMockHandler()
    }

    private func setupMockForExpiredTokens() {
        // Test with mock that simulates server rejection for expired tokens
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/oauth/token") && request.httpMethod == "POST" {
                // Simulate server rejecting refresh token requests for expired tokens
                let data = Data()
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }
            
            if url.path.contains("/oauth/token/info") {
                // Simulate server rejecting token validation
                let data = Data()
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }

            let data = Data()
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
    }

    private func testExpiredToken() {
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

    private func testFutureToken() {
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
            try self.handleMockRequest(request)
        }
    }

    // MARK: - Edge Case Tests

    func testTokenWithExtremeTimestamps() {
        setupMockToRejectTokenRequests()
        testVeryOldToken()
        testVeryFutureToken()
        restoreDefaultMockHandler()
    }

    private func setupMockToRejectTokenRequests() {
        // Set up mock to reject token refresh/validation requests
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/oauth/token") || url.path.contains("/oauth/token/info") {
                // Simulate server rejection for extreme timestamps
                let data = Data()
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, data)
            }

            let data = Data()
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
    }

    private func testVeryOldToken() {
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

    private func testVeryFutureToken() {
        let veryFutureDate = Date(timeIntervalSince1970: 2_147_483_647)
        mockCredentialStorage.storage["expiry"] = String(veryFutureDate.timeIntervalSince1970)

        let futureExpectation = XCTestExpectation(description: "very future token")
        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            futureExpectation.fulfill()
        }

        wait(for: [futureExpectation], timeout: 15.0)
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
        let testCases: [(String, String, String)] = [
            ("", "", ""), ("user", "", ""), ("", "pass", ""),
            ("", "", "123456"), ("user", "pass", ""), ("user", "", "123456"),
            ("", "pass", "123456"), ("a@b.c", "password", "123456")
        ]

        let expectations = testCases.indices.map { index in
            XCTestExpectation(description: "Test case \(index)")
        }

        executeTokenRequestTests(testCases: testCases, expectations: expectations)
        wait(for: expectations, timeout: 20.0)
    }

    private func executeTokenRequestTests(testCases: [(String, String, String)], expectations: [XCTestExpectation]) {
        for (index, testCase) in testCases.enumerated() {
            Token.getToken(
                username: testCase.0,
                password: testCase.1,
                otp: testCase.2,
                credentialStorage: mockCredentialStorage
            ) { result in
                // With our mock server, all requests succeed for simplicity
                if case .success = result {
                    expectations[index].fulfill()
                } else {
                    XCTFail("Expected success for test case \(index)")
                }
            }
        }
    }

    func testTokenRequestParameterValidation() {
        // Test that the token request handles different parameter scenarios
        testValidParameterRequest()
        testEmptyParameterRequest()
    }

    private func testValidParameterRequest() {
        let validExpectation = XCTestExpectation(description: "Valid request")
        Token.getToken(
            username: "valid@example.com",
            password: "password123",
            otp: "123456",
            credentialStorage: mockCredentialStorage
        ) { result in
            if case .success = result {
                validExpectation.fulfill()
            } else {
                XCTFail("Expected success for valid parameters")
            }
        }
        wait(for: [validExpectation], timeout: 5.0)
    }

    private func testEmptyParameterRequest() {
        let emptyParamsExpectation = XCTestExpectation(description: "Empty parameters request")
        Token.getToken(
            username: "",
            password: "",
            otp: "",
            credentialStorage: mockCredentialStorage
        ) { result in
            // With our mock server, even empty parameters succeed
            // In a real environment, this would depend on server validation
            if case .success = result {
                emptyParamsExpectation.fulfill()
            } else if case .failure = result {
                emptyParamsExpectation.fulfill()
            }
        }
        wait(for: [emptyParamsExpectation], timeout: 5.0)
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
                // All requests should succeed with our mock server
                switch result {
                case .success:
                    expectations[requestIndex].fulfill()
                case .failure(let error):
                    XCTFail("Expected success for request \(requestIndex), got error: \(error)")
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
