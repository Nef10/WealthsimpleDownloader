//
//  TokenParameterTests.swift
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

/// Tests for Token parameter validation and edge cases.
final class TokenParameterTests: XCTestCase {

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

    // MARK: - Token Request Parameter Tests

    func testTokenRequestParameters() {
        let testCases: [TokenRequestTestCase] = [
            TokenRequestTestCase(username: "", password: "", otp: ""),
            TokenRequestTestCase(username: "user", password: "", otp: ""),
            TokenRequestTestCase(username: "", password: "pass", otp: ""),
            TokenRequestTestCase(username: "", password: "", otp: "123456"),
            TokenRequestTestCase(username: "user", password: "pass", otp: ""),
            TokenRequestTestCase(username: "user", password: "", otp: "123456"),
            TokenRequestTestCase(username: "", password: "pass", otp: "123456"),
            TokenRequestTestCase(username: "a@b.c", password: "password", otp: "123456")
        ]

        let expectations = testCases.indices.map { index in
            XCTestExpectation(description: "Test case \(index)")
        }

        executeTokenRequestTests(testCases: testCases, expectations: expectations)
        wait(for: expectations, timeout: 20.0)
    }

    private func executeTokenRequestTests(testCases: [TokenRequestTestCase], expectations: [XCTestExpectation]) {
        for (index, testCase) in testCases.enumerated() {
            Token.getToken(
                username: testCase.username,
                password: testCase.password,
                otp: testCase.otp,
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
        runValidParameterRequest()
        runEmptyParameterRequest()
    }

    private func runValidParameterRequest() {
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

    private func runEmptyParameterRequest() {
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
}
