//
//  MockClasses.swift
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

// MARK: - Supporting Types

/// A mock implementation of CredentialStorage for testing purposes.
class MockCredentialStorage: CredentialStorage {
    var storage: [String: String] = [:]

    func save(_ value: String, for key: String) {
        storage[key] = value
    }

    func read(_ key: String) -> String? {
        storage[key]
    }
}

// MARK: - Test Case Structure

struct TokenRequestTestCase {
    let username: String
    let password: String
    let otp: String
}

// MARK: - Mock Classes

/// A mock URLProtocol implementation for intercepting HTTP requests during testing.
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // MARK: - Static Methods

    override class func canInit(with request: URLRequest) -> Bool {
        // Only handle requests to localhost
        request.url?.host == "localhost"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    static func handleMockRequest(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        if url.path.contains("/oauth/token") && request.httpMethod == "POST" {
            return try handleOAuthTokenRequest(url: url)
        }
        if url.path.contains("/oauth/token/info") && request.httpMethod == "GET" {
            return handleTokenInfoRequest(url: url, request: request)
        }
        return handleUnknownRequest(url: url)
    }

    private static func handleOAuthTokenRequest(url: URL) throws -> (HTTPURLResponse, Data) {
        let jsonResponse = [
            "access_token": "mock_access_token_12345",
            "refresh_token": "mock_refresh_token_67890",
            "expires_in": 3_600,
            "created_at": Int(Date().timeIntervalSince1970),
            "token_type": "Bearer"
        ] as [String: Any]

        let data = try JSONSerialization.data(withJSONObject: jsonResponse)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, data)
    }

    private static func handleTokenInfoRequest(url: URL, request: URLRequest) -> (HTTPURLResponse, Data) {
        let data = Data()
        let statusCode: Int

        if let authHeader = request.value(forHTTPHeaderField: "Authorization"),
           authHeader.contains("mock_access_token") {
            statusCode = 200
        } else {
            statusCode = 401
        }

        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private static func handleUnknownRequest(url: URL) -> (HTTPURLResponse, Data) {
        let data = Data()
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    // MARK: - Instance Methods

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
