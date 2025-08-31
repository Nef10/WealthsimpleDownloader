//
//  TokenNetworkTests.swift
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

/// Tests for Token network functionality and error handling.
final class TokenNetworkTests: XCTestCase {

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
            try MockURLProtocol.handleMockRequest(request)
        }
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
}
