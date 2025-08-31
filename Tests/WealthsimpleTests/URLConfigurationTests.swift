//
//  URLConfigurationTests.swift
//
//
// Created by Steffen Kötte on 2025-08-31.
//

import Foundation
@testable import Wealthsimple
import XCTest

final class URLConfigurationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to default base URL before each test
        URLConfiguration.shared.setBaseURL("https://api.production.wealthsimple.com/v1/")
    }

    func testDefaultBaseURL() {
        let config = URLConfiguration.shared
        XCTAssertEqual(config.base, "https://api.production.wealthsimple.com/v1/")
    }

    func testSetBaseURL() {
        let config = URLConfiguration.shared
        let testURL = "https://test.example.com/api/v2/"

        config.setBaseURL(testURL)

        XCTAssertEqual(config.base, testURL)
    }

    func testURLForPath() {
        let config = URLConfiguration.shared
        let result = config.url(for: "accounts")

        XCTAssertEqual(result, "https://api.production.wealthsimple.com/v1/accounts")
    }

    func testURLForPathWithCustomBase() {
        let config = URLConfiguration.shared
        config.setBaseURL("https://test.example.com/api/v2/")

        let result = config.url(for: "positions")

        XCTAssertEqual(result, "https://test.example.com/api/v2/positions")
    }

    func testURLObjectForPath() {
        let config = URLConfiguration.shared
        let result = config.urlObject(for: "transactions")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://api.production.wealthsimple.com/v1/transactions")
    }

    func testURLComponentsForPath() {
        let config = URLConfiguration.shared
        let result = config.urlComponents(for: "oauth/token")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.string, "https://api.production.wealthsimple.com/v1/oauth/token")
    }

    func testSingletonPattern() {
        let config1 = URLConfiguration.shared
        let config2 = URLConfiguration.shared

        XCTAssertIdentical(config1, config2)
    }

    func testConfigurationPersistsBetweenAccesses() {
        let config = URLConfiguration.shared
        let testURL = "https://mock.server.test/v1/"

        config.setBaseURL(testURL)

        // Access through different references
        let newConfig = URLConfiguration.shared
        XCTAssertEqual(newConfig.base, testURL)
    }

}
