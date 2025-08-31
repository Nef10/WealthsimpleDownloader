//
//  TokenBasicTests.swift
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

/// Tests for basic Token functionality and error cases.
final class TokenBasicTests: XCTestCase {

    private let tokenTestBase = TokenTestBase()

    override func setUp() {
        super.setUp()
        tokenTestBase.setUp()
    }

    override func tearDown() {
        super.tearDown()
        tokenTestBase.tearDown()
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
