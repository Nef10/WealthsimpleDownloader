//
//  TokenTests.swift
//
//
//  Created by Copilot on 2025-08-25.
//

import Foundation
@testable import Wealthsimple
import XCTest

class MockCredentialStorage: CredentialStorage {
    private var storage: [String: String] = [:]
    
    func save(_ value: String, for key: String) {
        storage[key] = value
    }
    
    func read(_ key: String) -> String? {
        return storage[key]
    }
}

final class TokenTests: XCTestCase {

    // Note: Cannot test Token instance methods since Token's init methods are private
    // and there's no public way to create Token instances for testing.
    // The Token class would need to expose a test-friendly initializer or factory method
    // to enable comprehensive testing of its non-network methods.
    
    func testMockCredentialStorage() {
        let storage = MockCredentialStorage()
        
        XCTAssertNil(storage.read("nonexistent"))
        
        storage.save("test-value", for: "test-key")
        XCTAssertEqual(storage.read("test-key"), "test-value")
        
        storage.save("updated-value", for: "test-key")
        XCTAssertEqual(storage.read("test-key"), "updated-value")
        
        storage.save("", for: "empty-key")
        XCTAssertEqual(storage.read("empty-key"), "")
    }
    
    func testCredentialStorageProtocol() {
        let storage: CredentialStorage = MockCredentialStorage()
        
        storage.save("protocol-test", for: "protocol-key")
        XCTAssertEqual(storage.read("protocol-key"), "protocol-test")
    }

}

// Note: We cannot test Token methods that require Token initialization since 
// the init methods are private and Token doesn't expose a public initializer.
// This test file is kept for reference but tests are disabled until Token 
// provides a test-friendly interface.