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

final class TokenTests: XCTestCase {

    private var mockCredentialStorage: MockCredentialStorage!

    override func setUp() {
        super.setUp()
        mockCredentialStorage = MockCredentialStorage()
        MockURLProtocol.setup()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - getToken with Credential Storage

    func testGetTokenFromCredentialStorageWithValidToken() {
        let expectation = XCTestExpectation(description: "getToken completion")

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set up valid token data in credential storage
        mockCredentialStorage.storage["accessToken"] = "mock_access_token_12345"
        mockCredentialStorage.storage["refreshToken"] = "mock_refresh_token_67890"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // This will just locally check expiry and do not do any network calls
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

    func testExpiredTokenFailsRefresh() {
        let requestExpectation = XCTestExpectation(description: "mock server caled")
        let getTokenExpectation = XCTestExpectation(description: "getToken completion")

        MockURLProtocol.newTokenRequestHandler = { url, _ in
            requestExpectation.fulfill()
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            XCTAssertNil(token)
            getTokenExpectation.fulfill()
        }

        wait(for: [getTokenExpectation, requestExpectation], timeout: 10.0)
    }

    // MARK: - getToken with Username/Password/OTP

    func testGetTokenWithUsernamePasswordOTPSuccess() {
        let tokenExpectation = XCTestExpectation(description: "getToken completion"), mockExpectation = XCTestExpectation(description: "mock server called")

        MockURLProtocol.newTokenRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-wealthsimple-otp"), "123456")
            // get JSON from POST request body stream
            let inputData = try Data(reading: request.httpBodyStream!)
            let json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            XCTAssertEqual(json?["username"] as? String, "test@example.com")
            XCTAssertEqual(json?["password"] as? String, "password1")
            XCTAssertEqual(json?["grant_type"] as? String, "password")
            XCTAssertEqual(json?["client_id"] as? String, "4da53ac2b03225bed1550eba8e4611e086c7b905a3855e6ed12ea08c246758fa")
            XCTAssertEqual(json?["scope"] as? String, "invest.read mfda.read mercer.read trade.read")

            let jsonResponse = [
                "access_token": "atoken12345", "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        Token.getToken(username: "test@example.com", password: "password1", otp: "123456", credentialStorage: mockCredentialStorage) { result in
            switch result {
            case .success(let token):
                XCTAssertNotNil(token)
                // Verify token was saved to credential storage
                XCTAssertEqual(self.mockCredentialStorage.read("accessToken"), "atoken12345")
                XCTAssertEqual(self.mockCredentialStorage.read("refreshToken"), "rtoken67890")
                XCTAssertNotNil(self.mockCredentialStorage.read("expiry"))
                tokenExpectation.fulfill()
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
        }

        wait(for: [mockExpectation, tokenExpectation], timeout: 10.0)
    }

    func testGetTokenWithUsernamePasswordOTPNetworkFailure() {
        // Set up the mock to throw an error for this test
        MockURLProtocol.newTokenRequestHandler = { _, _ in
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
    }

}
