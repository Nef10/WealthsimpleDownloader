//
//  MockURLProtocol.swift
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

/// A mock URLProtocol implementation for intercepting HTTP requests during testing.
class MockURLProtocol: URLProtocol {
    static var newTokenRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    static var tokenValidationRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    static var accountsRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    static var getPositionsRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest

    // MARK: - Static Methods

    override class func canInit(with request: URLRequest) -> Bool {
        // Only handle requests to localhost
        request.url?.host == "localhost"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    static func setup() {
        URLConfiguration.shared.setBaseURL("http://localhost:8080/v1/")
        _ = URLProtocol.registerClass(Self.self)
    }

    static func reset() {
        URLConfiguration.shared.reset()
        newTokenRequestHandler = failTest
        tokenValidationRequestHandler = failTest
        accountsRequestHandler = failTest
        getPositionsRequestHandler = failTest
        URLProtocol.unregisterClass(Self.self)
    }

    private static func handleMockRequest(_ request: URLRequest) throws -> (URLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        if url.path.contains("/oauth/token") && request.httpMethod == "POST" {
            return try newTokenRequestHandler(url, request)
        }
        if url.path.contains("/oauth/token/info") && request.httpMethod == "GET" {
            return try tokenValidationRequestHandler(url, request)
        }
        if url.path.contains("/accounts") && request.httpMethod == "GET" {
            return try accountsRequestHandler(url, request)
        }
        if url.path.contains("/positions") && request.httpMethod == "GET" {
            return try getPositionsRequestHandler(url, request)
        }

        XCTFail("Unexpected request: \(url)")
        throw URLError(.unsupportedURL)
    }

    static func failTest(url: URL, _: URLRequest) throws -> (HTTPURLResponse, Data) {
        XCTFail("Call network request which should not have been called")
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }

    // MARK: - Instance Methods

    override func startLoading() {
        do {
            let (response, data) = try Self.handleMockRequest(request)
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

extension Data {
    init(reading input: InputStream) throws {
        self.init()
        input.open()
        defer {
            input.close()
        }

        let bufferSize = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw input.streamError!
            }
            if read == 0 {
                break
            }
            self.append(buffer, count: read)
        }
    }
}
