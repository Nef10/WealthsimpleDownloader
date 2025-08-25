//
//  WealthsimpleAssetTests.swift
//
//
//  Created by Copilot on 2025-08-25.
//

import Foundation
@testable import Wealthsimple
import XCTest

final class WealthsimpleAssetTests: XCTestCase {

    func testAssetInitWithValidJSON() {
        let validJSON: [String: Any] = [
            "security_id": "test-id-123",
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc.",
            "type": "equity"
        ]
        
        XCTAssertNoThrow(try WealthsimpleAsset(json: validJSON))
        
        let asset = try! WealthsimpleAsset(json: validJSON)
        XCTAssertEqual(asset.id, "test-id-123")
        XCTAssertEqual(asset.symbol, "AAPL")
        XCTAssertEqual(asset.currency, "USD")
        XCTAssertEqual(asset.name, "Apple Inc.")
        XCTAssertEqual(asset.type, .equity)
    }
    
    func testAssetInitWithValidJSONAllTypes() {
        let types: [(String, AssetType)] = [
            ("currency", .currency),
            ("equity", .equity),
            ("mutual_fund", .mutualFund),
            ("bond", .bond),
            ("exchange_traded_fund", .exchangeTradedFund)
        ]
        
        for (typeString, expectedType) in types {
            let json: [String: Any] = [
                "security_id": "test-id",
                "symbol": "TEST",
                "currency": "CAD",
                "name": "Test Asset",
                "type": typeString
            ]
            
            XCTAssertNoThrow(try WealthsimpleAsset(json: json))
            let asset = try! WealthsimpleAsset(json: json)
            XCTAssertEqual(asset.type, expectedType)
        }
    }
    
    func testAssetInitWithMissingSecurityId() {
        let json: [String: Any] = [
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc.",
            "type": "equity"
        ]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.missingResultParamenter(let errorJson) = error else {
                XCTFail("Expected AssetError.missingResultParamenter, got \(error)")
                return
            }
            XCTAssertEqual(errorJson["symbol"] as? String, "AAPL")
        }
    }
    
    func testAssetInitWithMissingSymbol() {
        let json: [String: Any] = [
            "security_id": "test-id-123",
            "currency": "USD",
            "name": "Apple Inc.",
            "type": "equity"
        ]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.missingResultParamenter = error else {
                XCTFail("Expected AssetError.missingResultParamenter, got \(error)")
                return
            }
        }
    }
    
    func testAssetInitWithMissingCurrency() {
        let json: [String: Any] = [
            "security_id": "test-id-123",
            "symbol": "AAPL",
            "name": "Apple Inc.",
            "type": "equity"
        ]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.missingResultParamenter = error else {
                XCTFail("Expected AssetError.missingResultParamenter, got \(error)")
                return
            }
        }
    }
    
    func testAssetInitWithMissingName() {
        let json: [String: Any] = [
            "security_id": "test-id-123",
            "symbol": "AAPL",
            "currency": "USD",
            "type": "equity"
        ]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.missingResultParamenter = error else {
                XCTFail("Expected AssetError.missingResultParamenter, got \(error)")
                return
            }
        }
    }
    
    func testAssetInitWithMissingType() {
        let json: [String: Any] = [
            "security_id": "test-id-123",
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc."
        ]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.missingResultParamenter = error else {
                XCTFail("Expected AssetError.missingResultParamenter, got \(error)")
                return
            }
        }
    }
    
    func testAssetInitWithInvalidType() {
        let json: [String: Any] = [
            "security_id": "test-id-123",
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc.",
            "type": "invalid_type"
        ]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.invalidResultParamenter(let errorJson) = error else {
                XCTFail("Expected AssetError.invalidResultParamenter, got \(error)")
                return
            }
            XCTAssertEqual(errorJson["type"] as? String, "invalid_type")
        }
    }
    
    func testAssetInitWithWrongValueTypes() {
        let json: [String: Any] = [
            "security_id": 123, // Should be String
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc.",
            "type": "equity"
        ]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.missingResultParamenter = error else {
                XCTFail("Expected AssetError.missingResultParamenter, got \(error)")
                return
            }
        }
    }
    
    func testAssetInitWithEmptyJSON() {
        let json: [String: Any] = [:]
        
        XCTAssertThrowsError(try WealthsimpleAsset(json: json)) { error in
            guard case AssetError.missingResultParamenter = error else {
                XCTFail("Expected AssetError.missingResultParamenter, got \(error)")
                return
            }
        }
    }

}