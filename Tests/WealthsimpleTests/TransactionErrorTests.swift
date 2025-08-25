//
//  TransactionErrorTests.swift
//
//
//  Created by Copilot on 2025-08-25.
//

import Foundation
@testable import Wealthsimple
import XCTest

final class TransactionErrorTests: XCTestCase {

    func testTransactionErrorLocalizedDescriptions() {
        // Test noDataReceived
        let noDataError = TransactionError.noDataReceived
        XCTAssertEqual(noDataError.errorDescription, "No Data was received from the server")
        
        // Test httpError
        let httpError = TransactionError.httpError(error: "Connection failed")
        XCTAssertEqual(httpError.errorDescription, "An HTTP error occurred: Connection failed")
        
        // Test invalidJson
        let invalidJsonError = TransactionError.invalidJson(error: "Malformed JSON")
        XCTAssertEqual(invalidJsonError.errorDescription, "The server response contained invalid JSON: Malformed JSON")
        
        // Test invalidJsonType
        let testObject = ["key": "value"]
        let invalidJsonTypeError = TransactionError.invalidJsonType(json: testObject)
        XCTAssertEqual(invalidJsonTypeError.errorDescription, "The server response contained invalid JSON types: [\"key\": \"value\"]")
        
        // Test missingResultParamenter
        let missingParamJson = ["missing": "parameter"]
        let missingParamError = TransactionError.missingResultParamenter(json: missingParamJson)
        XCTAssertEqual(missingParamError.errorDescription, "The server response JSON was missing expected parameters: [\"missing\": \"parameter\"]")
        
        // Test invalidResultParamenter
        let invalidParamJson = ["invalid": "parameter"]
        let invalidParamError = TransactionError.invalidResultParamenter(json: invalidParamJson)
        XCTAssertEqual(invalidParamError.errorDescription, "The server response JSON contained invalid parameters: [\"invalid\": \"parameter\"]")
        
        // Test tokenError
        let tokenError = TransactionError.tokenError(.noToken)
        // The exact error description will depend on TokenError's implementation
        XCTAssertNotNil(tokenError.errorDescription)
        XCTAssertFalse(tokenError.errorDescription!.isEmpty)
    }
    
    func testTransactionErrorEquality() {
        // Test that same error types with same parameters are equal when possible
        let error1 = TransactionError.noDataReceived
        let error2 = TransactionError.noDataReceived
        
        // Note: We can't directly test equality since TransactionError doesn't conform to Equatable
        // But we can test that error descriptions are the same
        XCTAssertEqual(error1.errorDescription, error2.errorDescription)
        
        let httpError1 = TransactionError.httpError(error: "Same error")
        let httpError2 = TransactionError.httpError(error: "Same error")
        XCTAssertEqual(httpError1.errorDescription, httpError2.errorDescription)
        
        let httpError3 = TransactionError.httpError(error: "Different error")
        XCTAssertNotEqual(httpError1.errorDescription, httpError3.errorDescription)
    }
    
    func testTransactionErrorWithComplexJSONObjects() {
        let complexJson: [String: Any] = [
            "nested": [
                "array": [1, 2, 3],
                "string": "test",
                "bool": true
            ],
            "top_level": "value"
        ]
        
        let error = TransactionError.missingResultParamenter(json: complexJson)
        let description = error.errorDescription!
        
        // Verify the description contains information about the JSON
        XCTAssertTrue(description.contains("missing expected parameters"))
        XCTAssertTrue(description.contains("nested"))
        XCTAssertTrue(description.contains("top_level"))
    }
    
    func testTransactionErrorWithEmptyJSON() {
        let emptyJson: [String: Any] = [:]
        
        let error = TransactionError.invalidResultParamenter(json: emptyJson)
        let description = error.errorDescription!
        
        XCTAssertTrue(description.contains("invalid parameters"))
        XCTAssertTrue(description.contains("[:]") || description.contains("{}"))
    }

}