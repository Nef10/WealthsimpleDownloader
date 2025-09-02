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

    private func createValidToken(completion: @escaping (Token?) -> Void) {
        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            completion(token)
        }
    }

    private func setupMockForSuccess(
        accounts: [[String: Any]],
        expectations: (mock: XCTestExpectation, test: XCTestExpectation)
    ) {
        MockURLProtocol.accountsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")

            let jsonResponse = [
                "object": "account",
                "results": accounts
            ]
            expectations.mock.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
    }

    private func setupMockForError(
        response: (URLResponse, Data),
        expectation: XCTestExpectation
    ) {
        MockURLProtocol.accountsRequestHandler = { _, _ in
            expectation.fulfill()
            return response
        }
    }

    private func setupMockForThrow(
        error: Error,
        expectation: XCTestExpectation
    ) {
        MockURLProtocol.accountsRequestHandler = { _, _ in
            expectation.fulfill()
            throw error
        }
    }

    private func testAccountsFailure(
        mockSetup: (XCTestExpectation) -> Void,
        expectedError: @escaping (AccountError) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        mockSetup(mockExpectation)

        createValidToken { token in
            guard let token else {
                XCTFail("Failed to create valid token", file: file, line: line)
                expectation.fulfill()
                return
            }

            WealthsimpleAccount.getAccounts(token: token) { result in
                switch result {
                case .success:
                    XCTFail("Expected failure", file: file, line: line)
                case .failure(let error):
                    XCTAssertTrue(expectedError(error), "Unexpected error: \(error)", file: file, line: line)
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - Successful getAccounts Tests

    func testGetAccountsSuccess() {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        // Set up mock response for accounts endpoint
        MockURLProtocol.accountsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")

            let jsonResponse = [
                "object": "account",
                "results": [
                    [
                        "id": "account-123",
                        "type": "ca_tfsa",
                        "object": "account",
                        "base_currency": "CAD",
                        "custodian_account_number": "12345-67890"
                    ],
                    [
                        "id": "account-456",
                        "type": "ca_rrsp",
                        "object": "account",
                        "base_currency": "USD",
                        "custodian_account_number": "98765-43210"
                    ]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        createValidToken { token in
            guard let token else {
                XCTFail("Failed to create valid token")
                expectation.fulfill()
                return
            }

            WealthsimpleAccount.getAccounts(token: token) { result in
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
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetAccountsWithDifferentAccountTypes() {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        MockURLProtocol.accountsRequestHandler = { url, _ in
            let jsonResponse = [
                "object": "account",
                "results": [
                    [
                        "id": "account-1",
                        "type": "ca_cash_msb",
                        "object": "account",
                        "base_currency": "CAD",
                        "custodian_account_number": "12345"
                    ],
                    [
                        "id": "account-2",
                        "type": "ca_cash",
                        "object": "account",
                        "base_currency": "CAD",
                        "custodian_account_number": "23456"
                    ],
                    [
                        "id": "account-3",
                        "type": "ca_non_registered",
                        "object": "account",
                        "base_currency": "CAD",
                        "custodian_account_number": "34567"
                    ]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        createValidToken { token in
            guard let token else {
                XCTFail("Failed to create valid token")
                expectation.fulfill()
                return
            }

            WealthsimpleAccount.getAccounts(token: token) { result in
                switch result {
                case .success(let accounts):
                    XCTAssertEqual(accounts.count, 3)
                    XCTAssertEqual(accounts[0].accountType, .chequing)
                    XCTAssertEqual(accounts[1].accountType, .saving)
                    XCTAssertEqual(accounts[2].accountType, .nonRegistered)
                case .failure(let error):
                    XCTFail("Expected success but got error: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - Network Error Tests

    func testGetAccountsNetworkFailure() {
        testAccountsFailure(
            mockSetup: { expectation in
                setupMockForThrow(error: URLError(.networkConnectionLost), expectation: expectation)
            },
            expectedError: { error in
                if case .httpError = error {
                    return true
                }
                return false
            }
        )
    }

    func testGetAccountsInvalidJSONEmptyData() {
        testAccountsFailure(
            mockSetup: { expectation in
                let response = (
                    HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
                setupMockForError(response: response, expectation: expectation)
            },
            expectedError: { error in
                if case .invalidJson = error {
                    return true
                }
                return false
            }
        )
    }

    func testGetAccountsWrongResponseType() {
        testAccountsFailure(
            mockSetup: { expectation in
                let response = (
                    URLResponse(url: URL(string: "http://test.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
                    Data("test".utf8)
                )
                setupMockForError(response: response, expectation: expectation)
            },
            expectedError: { error in
                if case .httpError(let errorMessage) = error {
                    return errorMessage == "No HTTPURLResponse"
                }
                return false
            }
        )
    }

    func testGetAccountsHTTPError() {
        testAccountsFailure(
            mockSetup: { expectation in
                let response = (
                    HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
                setupMockForError(response: response, expectation: expectation)
            },
            expectedError: { error in
                if case .httpError(let errorMessage) = error {
                    return errorMessage == "Status code 401"
                }
                return false
            }
        )
    }

    private func testJSONParsingFailure(
        jsonData: Data,
        expectedError: @escaping (AccountError) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        testAccountsFailure(
            mockSetup: { expectation in
                let response = (
                    HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    jsonData
                )
                setupMockForError(response: response, expectation: expectation)
            },
            expectedError: expectedError,
            file: file,
            line: line
        )
    }

    private func testMissingFieldFailure(
        jsonObject: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            XCTFail("Failed to create JSON data", file: file, line: line)
            return
        }
        testJSONParsingFailure(
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
    ) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            XCTFail("Failed to create JSON data", file: file, line: line)
            return
        }
        testJSONParsingFailure(
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

    // MARK: - JSON Parsing Error Tests

    func testGetAccountsInvalidJSON() {
        testJSONParsingFailure(jsonData: Data("NOT VALID JSON".utf8)) { error in
            if case .invalidJson = error {
                return true
            }
            return false
        }
    }

    func testGetAccountsInvalidJSONType() {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            XCTFail("Failed to create test JSON data")
            return
        }
        testJSONParsingFailure(jsonData: jsonData) { error in
            if case .invalidJsonType = error {
                return true
            }
            return false
        }
    }

    func testGetAccountsMissingResults() {
        testMissingFieldFailure(jsonObject: ["object": "account"])
    }

    func testGetAccountsMissingObject() {
        testMissingFieldFailure(jsonObject: ["results": []])
    }

    func testGetAccountsInvalidObject() {
        testInvalidFieldFailure(jsonObject: ["object": "not_account", "results": []])
    }

    // MARK: - Individual Account JSON Parsing Tests

    func testGetAccountsMissingAccountId() {
        testMissingFieldFailure(jsonObject: [
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

    func testGetAccountsMissingAccountType() {
        testMissingFieldFailure(jsonObject: [
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

    func testGetAccountsInvalidAccountType() {
        testInvalidFieldFailure(jsonObject: [
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

    func testGetAccountsMissingCurrency() {
        testMissingFieldFailure(jsonObject: [
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

    func testGetAccountsMissingAccountNumber() {
        testMissingFieldFailure(jsonObject: [
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

    func testGetAccountsInvalidAccountObject() {
        testInvalidFieldFailure(jsonObject: [
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

    func testGetAccountsEmptyResults() {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        setupMockForSuccess(
            accounts: [],
            expectations: (mock: mockExpectation, test: expectation)
        )

        createValidToken { token in
            guard let token else {
                XCTFail("Failed to create valid token")
                expectation.fulfill()
                return
            }

            WealthsimpleAccount.getAccounts(token: token) { result in
                switch result {
                case .success(let accounts):
                    XCTAssertEqual(accounts.count, 0)
                case .failure(let error):
                    XCTFail("Expected success but got error: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

}
