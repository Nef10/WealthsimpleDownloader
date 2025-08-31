//
//  TokenTestBase.swift
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

/// Base class for token testing with shared setup and mock infrastructure.
class TokenTestBase {

    private var _mockCredentialStorage: MockCredentialStorage!
    private let _mockBaseURL = "http://localhost:8080/v1/"

    var mockCredentialStorage: MockCredentialStorage! {
        _mockCredentialStorage
    }

    var mockBaseURL: String {
        _mockBaseURL
    }

    func setUp() {
        _mockCredentialStorage = MockCredentialStorage()

        // Register mock URL protocol
        _ = URLProtocol.registerClass(MockURLProtocol.self)

        // Set up default request handler
        MockURLProtocol.requestHandler = { request in
            try MockURLProtocol.handleMockRequest(request)
        }

        URLConfiguration.shared.setBaseURL(_mockBaseURL)
    }

    func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        URLConfiguration.shared.setBaseURL("https://api.production.wealthsimple.com/v1/")
        MockURLProtocol.requestHandler = nil
        _mockCredentialStorage = nil
    }
}
