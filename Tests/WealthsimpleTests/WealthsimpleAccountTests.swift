//
//  WealthsimpleAccountTests.swift
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

final class WealthsimpleAccountTests: XCTestCase { // swiftlint:disable:this type_body_length

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

    // MARK: - Helper Methods

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

    private func setupMockForSuccess(accounts: [[String: Any]], expectation: XCTestExpectation) {
        MockURLProtocol.accountsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token1")

            let jsonResponse = [
                "object": "account",
                "results": accounts
            ]
            expectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
    }

    private func testAccountsFailure(response: (URLResponse, Data), expectedError: @escaping (AccountError) -> Bool, file: StaticString = #file, line: UInt = #line) throws {
        let mockExpectation = XCTestExpectation(description: "mock server called")

        try testAccountsFailure(
            response: { _, _ in
                mockExpectation.fulfill()
                return response
            },
            expectedError: expectedError,
            file: file,
            line: line
        )

        wait(for: [mockExpectation], timeout: 10.0)

    }

    private func testAccountsFailure(
        response: @escaping ((URL, URLRequest) throws -> (URLResponse, Data)),
        expectedError: @escaping (AccountError) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")

        MockURLProtocol.accountsRequestHandler = response

        WealthsimpleAccount.getAccounts(token: try createValidToken()) { result in
            switch result {
            case .success:
                XCTFail("Expected failure", file: file, line: line)
            case .failure(let error):
                XCTAssertTrue(expectedError(error), "Unexpected error: \(error)", file: file, line: line)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Successful getAccounts Tests

    func testGetAccountsSuccess() throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        setupMockForSuccess(accounts:
            [
                ["id": "account-123", "type": "ca_tfsa", "object": "account", "base_currency": "CAD", "custodian_account_number": "12345-67890"],
                ["id": "account-456", "type": "ca_rrsp", "object": "account", "base_currency": "USD", "custodian_account_number": "98765-43210"]
            ],
            expectation: mockExpectation
        )

        WealthsimpleAccount.getAccounts(token: try createValidToken()) { result in
            switch result {
            case .success(let accounts):
                XCTAssertEqual(accounts.count, 2)

                let firstAccount = accounts[0]
                XCTAssertEqual(firstAccount.id, "account-123")
                XCTAssertEqual(firstAccount.accountType, .tfsa)
                XCTAssertEqual(firstAccount.currency, "CAD")
                XCTAssertEqual(firstAccount.number, "12345-67890")

                let secondAccount = accounts[1]
                XCTAssertEqual(secondAccount.id, "account-456")
                XCTAssertEqual(secondAccount.accountType, .rrsp)
                XCTAssertEqual(secondAccount.currency, "USD")
                XCTAssertEqual(secondAccount.number, "98765-43210")

            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetAccountsEmptyResults() throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        setupMockForSuccess(accounts: [], expectation: mockExpectation)

        WealthsimpleAccount.getAccounts(token: try createValidToken()) { result in
            switch result {
            case .success(let accounts):
                XCTAssertEqual(accounts.count, 0)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - Network Error Tests

    func testGetAccountsNetworkFailure() throws {
        try testAccountsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: { error in
                if case .httpError = error {
                    return true
                }
                return false
            }
        )
    }

    func testGetAccountsInvalidJSONEmptyData() throws {
        try testAccountsFailure(response: (
            HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            Data()
        )) { error in
            if case .invalidJson = error {
                return true
            }
            return false
        }
    }

    func testGetAccountsWrongResponseType() throws {
        try testAccountsFailure(response: (
            URLResponse(url: URL(string: "http://test.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
            Data("test".utf8)
        )) { error in
            if case .httpError(let errorMessage) = error {
                return errorMessage == "No HTTPURLResponse"
            }
            return false
        }
    }

    func testGetAccountsHTTPError() throws {
        try testAccountsFailure(response: (
            HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
            Data()
        )) { error in
            if case .httpError(let errorMessage) = error {
                return errorMessage == "Status code 401"
            }
            return false
        }
    }

    // MARK: - JSON Parsing Error Tests

    private func testJSONParsingFailure(
        jsonData: Data,
        expectedError: @escaping (AccountError) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        try testAccountsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                jsonData
            ),
            expectedError: expectedError,
            file: file,
            line: line)
    }

    private func testMissingFieldFailure(
        jsonObject: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            XCTFail("Failed to create JSON data", file: file, line: line)
            return
        }
        try testJSONParsingFailure(
            jsonData: jsonData,
            expectedError: { error in
                if case .missingResultParamenter = error {
                    return true
                }
                return false
            },
            file: file,
            line: line
        )
    }

    private func testInvalidFieldFailure(
        jsonObject: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            XCTFail("Failed to create JSON data", file: file, line: line)
            return
        }
        try testJSONParsingFailure(
            jsonData: jsonData,
            expectedError: { error in
                if case .invalidResultParamenter = error {
                    return true
                }
                return false
            },
            file: file,
            line: line
        )
    }

    func testGetAccountsInvalidJSON() throws {
        try testJSONParsingFailure(jsonData: Data("NOT VALID JSON".utf8)) { error in
            if case .invalidJson = error {
                return true
            }
            return false
        }
    }

    func testGetAccountsInvalidJSONType() throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            XCTFail("Failed to create test JSON data")
            return
        }
        try testJSONParsingFailure(jsonData: jsonData) { error in
            if case .invalidJsonType = error {
                return true
            }
            return false
        }
    }

    func testGetAccountsMissingResults() throws {
        try testMissingFieldFailure(jsonObject: ["object": "account"])
    }

    func testGetAccountsMissingObject() throws {
        try testMissingFieldFailure(jsonObject: ["results": []])
    }

    func testGetAccountsInvalidObject() throws {
        try testInvalidFieldFailure(jsonObject: ["object": "not_account", "results": []])
    }

    // MARK: - Individual Account JSON Parsing Tests

    func testGetAccountsMissingAccountId() throws {
        try testMissingFieldFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "type": "ca_tfsa",
                    "object": "account",
                    "base_currency": "CAD",
                    "custodian_account_number": "12345"
                ]
            ]
        ])
    }

    func testGetAccountsMissingAccountType() throws {
        try testMissingFieldFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "id": "account-123",
                    "object": "account",
                    "base_currency": "CAD",
                    "custodian_account_number": "12345"
                ]
            ]
        ])
    }

    func testGetAccountsInvalidAccountType() throws {
        try testInvalidFieldFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "id": "account-123",
                    "type": "invalid_account_type",
                    "object": "account",
                    "base_currency": "CAD",
                    "custodian_account_number": "12345"
                ]
            ]
        ])
    }

    func testGetAccountsMissingCurrency() throws {
        try testMissingFieldFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "id": "account-123",
                    "type": "ca_tfsa",
                    "object": "account",
                    "custodian_account_number": "12345"
                ]
            ]
        ])
    }

    func testGetAccountsMissingAccountNumber() throws {
        try testMissingFieldFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "id": "account-123",
                    "type": "ca_tfsa",
                    "object": "account",
                    "base_currency": "CAD"
                ]
            ]
        ])
    }

    func testGetAccountsInvalidAccountObject() throws {
        try testInvalidFieldFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "id": "account-123",
                    "type": "ca_tfsa",
                    "object": "not_account",
                    "base_currency": "CAD",
                    "custodian_account_number": "12345"
                ]
            ]
        ])
    }

}
