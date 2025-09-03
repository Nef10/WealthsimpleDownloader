//
//  WealthsimpleDownloaderTests.swift
//
//
//  Created by Steffen Kötte on 2025-09-02.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Wealthsimple
import XCTest

final class WealthsimpleDownloaderTests: DownloaderTestCase {

    private var downloader: WealthsimpleDownloader!

    // MARK: - Helper Methods

    private func createDownloader(withAuthCallback callback: @escaping WealthsimpleDownloader.AuthenticationCallback) -> WealthsimpleDownloader {
        WealthsimpleDownloader(authenticationCallback: callback, credentialStorage: mockCredentialStorage)
    }

    private func createValidToken() throws -> Token {
        let expectation = XCTestExpectation(description: "createValidToken completion")
        var resultToken: Token?

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "valid_access_token1"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            resultToken = token
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        guard let resultToken else {
            XCTFail("Did not get valid token")
            throw TokenError.noToken
        }
        return resultToken
    }

    // MARK: - Constructor Tests

    func testInit() {
        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { _ in
            // Mock callback - unused in this test
        }

        let downloader = createDownloader(withAuthCallback: authCallback)

        // Test that downloader was created (no direct way to test private properties)
        XCTAssertNotNil(downloader)
    }

    // MARK: - Authenticate Tests

    func testAuthenticateWithExistingTokenRefreshSuccess() {
        let expectation = XCTestExpectation(description: "authenticate completion")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            XCTFail("Auth callback should not be called when credential storage has valid token")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testAuthenticateWithExistingTokenRefreshFailure() {
        let expectation = XCTestExpectation(description: "authenticate completion")
        let authExpectation = XCTestExpectation(description: "auth callback called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            authExpectation.fulfill()
            completion("testuser", "testpass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Set up refresh to fail, then new token to succeed
        MockURLProtocol.newTokenRequestHandler = { url, request in
            let jsonResponse = [
                "access_token": "new_access_token",
                "refresh_token": "new_refresh_token",
                "expires_in": 3_600,
                "created_at": Int(Date().timeIntervalSince1970),
                "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        // Set expired token - this will trigger getNewToken since no valid token in storage
        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation, authExpectation], timeout: 10.0)
    }

    func testAuthenticateWithoutTokenValidCredentialStorage() {
        let expectation = XCTestExpectation(description: "authenticate completion")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            XCTFail("Auth callback should not be called when credential storage has valid token")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testAuthenticateWithoutTokenEmptyCredentialStorage() {
        let expectation = XCTestExpectation(description: "authenticate completion")
        let authExpectation = XCTestExpectation(description: "auth callback called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            authExpectation.fulfill()
            completion("testuser", "testpass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        MockURLProtocol.newTokenRequestHandler = { url, _ in
            let jsonResponse = [
                "access_token": "new_access_token",
                "refresh_token": "new_refresh_token",
                "expires_in": 3_600,
                "created_at": Int(Date().timeIntervalSince1970),
                "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation, authExpectation], timeout: 10.0)
    }

    func testAuthenticateWithNewTokenFailure() {
        let expectation = XCTestExpectation(description: "authenticate completion")
        let authExpectation = XCTestExpectation(description: "auth callback called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            authExpectation.fulfill()
            completion("testuser", "testpass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        MockURLProtocol.newTokenRequestHandler = { url, _ in
            throw URLError(.networkConnectionLost)
        }

        downloader.authenticate { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation, authExpectation], timeout: 10.0)
    }

    // MARK: - getAccounts Tests

    func testGetAccountsWithoutToken() {
        let expectation = XCTestExpectation(description: "getAccounts completion")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        downloader.getAccounts { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to no token")
            case .failure(let error):
                if case .tokenError(let tokenError) = error {
                    XCTAssertEqual(tokenError, .noToken)
                } else {
                    XCTFail("Expected tokenError(.noToken)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetAccountsWithTokenSuccess() throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Setup mock for successful accounts response
        MockURLProtocol.accountsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")

            let jsonResponse = [
                "object": "account",
                "results": [
                    ["id": "account-123", "type": "ca_tfsa", "object": "account", "base_currency": "CAD", "custodian_account_number": "12345-67890"]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)

            self.downloader.getAccounts { result in
                switch result {
                case .success(let accounts):
                    XCTAssertEqual(accounts.count, 1)
                    XCTAssertEqual(accounts[0].id, "account-123")
                case .failure:
                    XCTFail("Expected success")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetAccountsWithHttpError() throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Setup mock to return HTTP error
        MockURLProtocol.accountsRequestHandler = { url, request in
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)

            self.downloader.getAccounts { result in
                switch result {
                case .success:
                    XCTFail("Expected failure")
                case .failure(let error):
                    if case .httpError = error {
                        // This is expected - 401 becomes httpError
                    } else {
                        XCTFail("Expected httpError but got \(error)")
                    }
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetAccountsWithNetworkError() throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Setup mock to throw network error
        MockURLProtocol.accountsRequestHandler = { url, request in
            mockExpectation.fulfill()
            throw URLError(.networkConnectionLost)
        }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)

            self.downloader.getAccounts { result in
                switch result {
                case .success:
                    XCTFail("Expected failure")
                case .failure:
                    // Expected network error
                    break
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - getPositions Tests

    func testGetPositionsWithoutToken() {
        let expectation = XCTestExpectation(description: "getPositions completion")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Create a mock account
        let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")

        downloader.getPositions(in: mockAccount, date: nil) { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to no token")
            case .failure(let error):
                if case .tokenError(let tokenError) = error {
                    XCTAssertEqual(tokenError, .noToken)
                } else {
                    XCTFail("Expected tokenError(.noToken)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetPositionsWithTokenSuccess() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Setup mock for successful positions response
        MockURLProtocol.positionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")

            let jsonResponse = [
                "object": "position",
                "results": [
                    [
                        "id": "position-123",
                        "object": "position",
                        "account_id": "account-123",
                        "quantity": "10.0",
                        "market_price": ["amount": "110.0", "currency": "CAD"],
                        "position_date": "2024-01-01",
                        "asset": [
                            "security_id": "asset-123",
                            "object": "asset",
                            "currency": "CAD",
                            "symbol": "XIC",
                            "name": "iShares Core S&P TSX Index ETF",
                            "type": "exchange_traded_fund"
                        ]
                    ]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // Create a mock account
        let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)

            self.downloader.getPositions(in: mockAccount, date: nil) { result in
                switch result {
                case .success(let positions):
                    XCTAssertEqual(positions.count, 1)
                case .failure:
                    XCTFail("Expected success")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetPositionsWithNetworkError() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Setup mock to throw network error
        MockURLProtocol.positionsRequestHandler = { url, request in
            mockExpectation.fulfill()
            throw URLError(.networkConnectionLost)
        }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // Create a mock account
        let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)

            self.downloader.getPositions(in: mockAccount, date: nil) { result in
                switch result {
                case .success:
                    XCTFail("Expected failure")
                case .failure:
                    // Expected network error
                    break
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - getTransactions Tests

    func testGetTransactionsWithoutToken() {
        let expectation = XCTestExpectation(description: "getTransactions completion")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Create a mock account
        let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")

        downloader.getTransactions(in: mockAccount, startDate: nil) { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to no token")
            case .failure(let error):
                if case .tokenError(let tokenError) = error {
                    XCTAssertEqual(tokenError, .noToken)
                } else {
                    XCTFail("Expected tokenError(.noToken)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetTransactionsWithTokenSuccess() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Setup mock for successful transactions response
        MockURLProtocol.transactionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")

            let jsonResponse = [
                "object": "transaction",
                "results": [
                    [
                        "id": "transaction-123",
                        "object": "transaction",
                        "account_id": "account-123",
                        "description": "Test transaction",
                        "type": "buy",
                        "symbol": "XIC",
                        "quantity": "10.0",
                        "market_price": ["amount": "100.0", "currency": "CAD"],
                        "market_value": ["amount": "1000.0", "currency": "CAD"],
                        "net_cash": ["amount": "-1000.0", "currency": "CAD"],
                        "process_date": "2024-01-01",
                        "effective_date": "2024-01-01",
                        "fx_rate": "1.0"
                    ]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // Create a mock account
        let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)

            self.downloader.getTransactions(in: mockAccount, startDate: nil) { result in
                switch result {
                case .success(let transactions):
                    XCTAssertEqual(transactions.count, 1)
                case .failure:
                    XCTFail("Expected success")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetTransactionsWithNetworkError() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let authCallback: WealthsimpleDownloader.AuthenticationCallback = { completion in
            completion("user", "pass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        // Setup mock to throw network error
        MockURLProtocol.transactionsRequestHandler = { url, request in
            mockExpectation.fulfill()
            throw URLError(.networkConnectionLost)
        }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // Create a mock account
        let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)

            self.downloader.getTransactions(in: mockAccount, startDate: nil) { result in
                switch result {
                case .success:
                    XCTFail("Expected failure")
                case .failure:
                    // Expected network error
                    break
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

}
