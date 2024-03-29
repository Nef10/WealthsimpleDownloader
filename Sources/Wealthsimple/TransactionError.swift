//
//  TransactionError.swift
//
//
//  Created by Steffen Koette on 2021-04-21.
//

import Foundation

/// Errors which can happen when retrieving a Transaction
public enum TransactionError: Error {
    /// When no data is received from the HTTP request
    case noDataReceived
    /// When an HTTP error occurs
    case httpError(error: String)
    /// When the received data is not valid JSON
    case invalidJson(error: String)
    /// When the received JSON does not have the right type
    case invalidJsonType(json: Any)
    /// When the received JSON does not have all expected values
    case missingResultParamenter(json: [String: Any])
    /// When the received JSON does have an unexpected value
    case invalidResultParamenter(json: [String: Any])
    /// An error with the token occured
    case tokenError(_ error: TokenError)
}

extension TransactionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noDataReceived:
            return "No Data was received from the server"
        case let .httpError(error):
            return "An HTTP error occurred: \(error)"
        case let .invalidJson(error):
            return "The server response contained invalid JSON: \(error)"
        case let .invalidJsonType(error):
            return "The server response contained invalid JSON types: \(error)"
        case let .missingResultParamenter(json):
            return "The server response JSON was missing expected parameters: \(json)"
        case let .invalidResultParamenter(json):
            return "The server response JSON contained invalid parameters: \(json)"
        case let .tokenError(error):
            return error.localizedDescription
        }
    }
}
