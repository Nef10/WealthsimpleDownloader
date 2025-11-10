//
//
//  TransactionTests.swift
//
//
//  Created by Steffen Kötte on 2025-11-09.
//

import Foundation
@testable import Wealthsimple
import XCTest

final class TransactionTests: XCTestCase {

    func testTransactionErrorLocalizedDescription() {
        XCTAssertEqual(TransactionError.noDataReceived.errorDescription, "No Data was received from the server")
        XCTAssertEqual(TransactionError.httpError(error: "Test HTTP Error").errorDescription, "An HTTP error occurred: Test HTTP Error")
        let invalidJsonData = Data("invalid".utf8)
        XCTAssertEqual(TransactionError.invalidJson(json: invalidJsonData).errorDescription, "The server response contained invalid JSON: \(invalidJsonData)")
        let missingJson = ["missing": true as Any]
        XCTAssertNoThrow(try {
            let missingJsonStr = try String(data: JSONSerialization.data(withJSONObject: missingJson), encoding: .utf8)!
            XCTAssertEqual(
                TransactionError.missingResultParameter(json: missingJson).errorDescription,
                "The server response JSON was missing expected parameters: \(missingJsonStr)"
            )
            let invalidJson = ["invalid": true as Any]
            let invalidJsonStr = try String(data: JSONSerialization.data(withJSONObject: invalidJson), encoding: .utf8)!
            XCTAssertEqual(
                TransactionError.invalidResultParameter(json: invalidJson).errorDescription,
                "The server response JSON contained invalid parameters: \(invalidJsonStr)"
            )
        }())
        let tokenError = TokenError.noToken
        XCTAssertEqual(TransactionError.tokenError(tokenError).errorDescription, tokenError.localizedDescription)
    }

}
