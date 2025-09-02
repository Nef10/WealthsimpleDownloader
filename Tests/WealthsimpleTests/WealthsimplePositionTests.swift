// swiftlint:disable file_length

//
//  WealthsimplePositionTests.swift
//
//
//  Created by Steffen Kötte on 2025-09-02.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Wealthsimple
import XCTest

// Mock Account implementation for testing
private struct MockAccount: Account {
    let id: String
    let accountType: AccountType
    let currency: String
    let number: String
}

final class WealthsimplePositionTests: XCTestCase { // swiftlint:disable:this type_body_length

    private var mockCredentialStorage: MockCredentialStorage!

    override func setUp() {
        super.setUp()
        mockCredentialStorage = MockCredentialStorage()
        MockURLProtocol.setup()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createValidToken() throws -> Token {
        let expectation = XCTestExpectation(description: "createValidToken completion")
        var resultToken: Token?

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            resultToken = token
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        return try XCTUnwrap(resultToken)
    }

    private func createMockAccount() -> Account {
        MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345-67890")
    }

    private func createValidPositionJSON() -> [String: Any] {
        [
            "quantity": "100.0",
            "account_id": "account-123",
            "asset": [
                "security_id": "asset-123",
                "symbol": "AAPL",
                "currency": "USD",
                "name": "Apple Inc.",
                "type": "equity"
            ],
            "market_price": [
                "amount": "150.25",
                "currency": "USD"
            ],
            "position_date": "2023-12-01",
            "object": "position"
        ]
    }

    private func createValidPositionsResponseJSON() -> [String: Any] {
        [
            "object": "position",
            "results": [
                createValidPositionJSON(),
                [
                    "quantity": "50.0",
                    "account_id": "account-123",
                    "asset": [
                        "security_id": "asset-456",
                        "symbol": "GOOGL",
                        "currency": "USD",
                        "name": "Alphabet Inc.",
                        "type": "equity"
                    ],
                    "market_price": [
                        "amount": "120.75",
                        "currency": "USD"
                    ],
                    "position_date": "2023-12-01",
                    "object": "position"
                ]
            ]
        ]
    }

    // MARK: - Helper Methods for Testing

    private func setupMockForSuccess(positions: [[String: Any]], expectation: XCTestExpectation) {
        MockURLProtocol.getPositionsRequestHandler = { url, _ in
            expectation.fulfill()
            let responseJSON: [String: Any] = [
                "object": "position",
                "results": positions
            ]
            let responseData = try JSONSerialization.data(withJSONObject: responseJSON, options: [])
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseData)
        }
    }

    private func testPositionsFailure(
        response: @escaping (URL, URLRequest) throws -> (URLResponse, Data),
        expectedError: PositionError,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "getPositions completion")

        MockURLProtocol.getPositionsRequestHandler = response

        WealthsimplePosition.getPositions(token: try createValidToken(), account: createMockAccount(), date: nil) { result in
            switch result {
            case .success:
                XCTFail("Expected failure", file: file, line: line)
            case .failure(let error):
                XCTAssertEqual(error, expectedError, file: file, line: line)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    private func testJSONParsingFailure(
        jsonData: Data,
        expectedError: PositionError,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        try testPositionsFailure(
            response: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, jsonData)
            },
            expectedError: expectedError,
            file: file,
            line: line
        )
    }

    private func testJSONParsingFailure(
        jsonObject: [String: Any],
        expectedError: PositionError,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            XCTFail("Failed to create JSON data", file: file, line: line)
            return
        }
        try testJSONParsingFailure(jsonData: jsonData, expectedError: expectedError, file: file, line: line)
    }

    // MARK: - Successful getPositions Tests

    func testGetPositionsSuccess() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        setupMockForSuccess(positions: [createValidPositionJSON()], expectation: mockExpectation)

        WealthsimplePosition.getPositions(token: try createValidToken(), account: createMockAccount(), date: nil) { result in
            switch result {
            case .success(let positions):
                XCTAssertEqual(positions.count, 1)
                let position = positions[0]
                XCTAssertEqual(position.accountId, "account-123")
                XCTAssertEqual(position.quantity, "100.0")
                XCTAssertEqual(position.priceAmount, "150.25")
                XCTAssertEqual(position.priceCurrency, "USD")
                XCTAssertEqual(position.asset.symbol, "AAPL")
                XCTAssertEqual(position.asset.name, "Apple Inc.")
                XCTAssertEqual(position.asset.currency, "USD")
                XCTAssertEqual(position.asset.type, .equity)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = dateFormatter.date(from: "2023-12-01")!
        XCTAssertEqual(position.positionDate, expectedDate)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetPositionsSuccessWithDate() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        MockURLProtocol.getPositionsRequestHandler = { url, _ in
            // Verify that the date parameter is included in the request
            XCTAssertEqual(url.query?.contains("date=2023-12-01"), true)
            mockExpectation.fulfill()
            let responseJSON = self.createValidPositionsResponseJSON()
            let responseData = try JSONSerialization.data(withJSONObject: responseJSON, options: [])
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseData)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatter.date(from: "2023-12-01")!

        WealthsimplePosition.getPositions(token: try createValidToken(), account: createMockAccount(), date: testDate) { result in
            switch result {
            case .success(let positions):
                XCTAssertEqual(positions.count, 2)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetPositionsSuccessMultiplePositions() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        guard let results = createValidPositionsResponseJSON()["results"] as? [[String: Any]] else {
            XCTFail("Failed to extract results from response JSON")
            return
        }
        setupMockForSuccess(positions: results, expectation: mockExpectation)

        WealthsimplePosition.getPositions(token: try createValidToken(), account: createMockAccount(), date: nil) { result in
            switch result {
            case .success(let positions):
                XCTAssertEqual(positions.count, 2)

                let firstPosition = positions[0]
                XCTAssertEqual(firstPosition.accountId, "account-123")
                XCTAssertEqual(firstPosition.quantity, "100.0")
                XCTAssertEqual(firstPosition.asset.symbol, "AAPL")

                let secondPosition = positions[1]
                XCTAssertEqual(secondPosition.accountId, "account-123")
                XCTAssertEqual(secondPosition.quantity, "50.0")
                XCTAssertEqual(secondPosition.asset.symbol, "GOOGL")
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - Network Failure Tests

    func testGetPositionsNetworkFailure() throws {
        try testPositionsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: PositionError.httpError(error: "The operation could not be completed. (NSURLErrorDomain error -1005.)")
        )
    }

    func testGetPositionsInvalidJSONEmptyData() throws {
        try testPositionsFailure(response: { url, _ in
            (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }, expectedError: PositionError.invalidJson(error: "The operation could not be completed. The data is not in the correct format."))
    }

    func testGetPositionsWrongResponseType() throws {
        try testPositionsFailure(response: { url, _ in
            (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data("test".utf8))
        }, expectedError: PositionError.httpError(error: "No HTTPURLResponse"))
    }

    func testGetPositionsHTTPError() throws {
        try testPositionsFailure(response: { url, _ in
            (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }, expectedError: PositionError.httpError(error: "Status code 401"))
    }

    // MARK: - JSON Parsing Error Tests

    func testGetPositionsInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testJSONParsingFailure(
            jsonData: data,
            expectedError: PositionError.invalidJson(error: "The operation could not be completed. The data is not in the correct format.")
        )
    }

    func testGetPositionsInvalidJSONType() throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            XCTFail("Failed to create test JSON data")
            return
        }
        try testJSONParsingFailure(
            jsonData: jsonData,
            expectedError: PositionError.invalidJsonType(json: ["not", "a", "dictionary"])
        )
    }

    func testGetPositionsMissingResults() throws {
        try testJSONParsingFailure(jsonObject: ["object": "position"], expectedError: PositionError.missingResultParamenter(json: ["object": "position"]))
    }

    func testGetPositionsInvalidObject() throws {
        try testJSONParsingFailure(
            jsonObject: ["object": "not_position", "results": []],
            expectedError: PositionError.invalidResultParamenter(json: ["object": "not_position", "results": []])
        )
    }

    func testGetPositionsMissingQuantity() throws {
        var json = createValidPositionJSON()
        json.removeValue(forKey: "quantity")
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsMissingAccountId() throws {
        var json = createValidPositionJSON()
        json.removeValue(forKey: "account_id")
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsMissingAsset() throws {
        var json = createValidPositionJSON()
        json.removeValue(forKey: "asset")
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsMissingMarketPrice() throws {
        var json = createValidPositionJSON()
        json.removeValue(forKey: "market_price")
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsMissingPositionDate() throws {
        var json = createValidPositionJSON()
        json.removeValue(forKey: "position_date")
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsMissingObject() throws {
        var json = createValidPositionJSON()
        json.removeValue(forKey: "object")
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsMissingPriceAmount() throws {
        var json = createValidPositionJSON()
        guard var marketPrice = json["market_price"] as? [String: Any] else {
            XCTFail("Failed to extract market_price")
            return
        }
        marketPrice.removeValue(forKey: "amount")
        json["market_price"] = marketPrice
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsMissingPriceCurrency() throws {
        var json = createValidPositionJSON()
        guard var marketPrice = json["market_price"] as? [String: Any] else {
            XCTFail("Failed to extract market_price")
            return
        }
        marketPrice.removeValue(forKey: "currency")
        json["market_price"] = marketPrice
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.missingResultParamenter(json: json))
    }

    func testGetPositionsInvalidDate() throws {
        var json = createValidPositionJSON()
        json["position_date"] = "invalid-date"
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.invalidResultParamenter(json: json))
    }

    func testGetPositionsInvalidObjectInPosition() throws {
        var json = createValidPositionJSON()
        json["object"] = "not_position"
        try testJSONParsingFailure(jsonObject: [
            "object": "position",
            "results": [json]
        ], expectedError: PositionError.invalidResultParamenter(json: json))
    }

    // swiftlint:disable:next function_body_length
    func testGetPositionsInvalidAsset() throws {
        var json = createValidPositionJSON()
        json["asset"] = [
            "security_id": "asset-123",
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc."
            // missing "type"
        ]
        // The error should be an assetError, but we need to check the actual error type
        let expectation = XCTestExpectation(description: "getPositions completion")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: [
            "object": "position",
            "results": [json]
        ], options: []) else {
            XCTFail("Failed to create JSON data")
            return
        }

        MockURLProtocol.getPositionsRequestHandler = { url, _ in
            (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, jsonData)
        }

        WealthsimplePosition.getPositions(token: try createValidToken(), account: createMockAccount(), date: nil) { result in
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                if case .assetError = error {
                    // Expected error
                } else {
                    XCTFail("Expected assetError but got \(error)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Additional Error Coverage Tests

    func testGetPositionsNoDataReceived() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")

        MockURLProtocol.getPositionsRequestHandler = { url, _ in
            (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        // This will test the case where data is nil (which we simulate by returning empty data and expecting an error)
        WealthsimplePosition.getPositions(token: try createValidToken(), account: createMockAccount(), date: nil) { result in
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                // The error will actually be invalidJson because empty data fails JSON parsing
                if case .invalidJson = error {
                    // Expected error
                } else {
                    XCTFail("Expected invalidJson error but got \(error)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetPositionsAssetTypeVariations() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let positions = createAssetTypeVariationPositions()
        setupMockForSuccess(positions: positions, expectation: mockExpectation)

        WealthsimplePosition.getPositions(token: try createValidToken(), account: createMockAccount(), date: nil) { result in
            switch result {
            case .success(let positionList):
                self.validateAssetTypeVariations(positionList)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // swiftlint:disable:next function_body_length
    private func createAssetTypeVariationPositions() -> [[String: Any]] {
        [
            // Mutual fund
            [
                "quantity": "25.0",
                "account_id": "account-123",
                "asset": [
                    "security_id": "asset-789",
                    "symbol": "MFC",
                    "currency": "CAD",
                    "name": "Mutual Fund Corp",
                    "type": "mutual_fund"
                ],
                "market_price": [
                    "amount": "75.50",
                    "currency": "CAD"
                ],
                "position_date": "2023-12-01",
                "object": "position"
            ],
            // Currency
            [
                "quantity": "1000.0",
                "account_id": "account-123",
                "asset": [
                    "security_id": "asset-USD",
                    "symbol": "USD",
                    "currency": "USD",
                    "name": "US Dollar",
                    "type": "currency"
                ],
                "market_price": [
                    "amount": "1.0",
                    "currency": "USD"
                ],
                "position_date": "2023-12-01",
                "object": "position"
            ]
        ]
    }

    private func validateAssetTypeVariations(_ positionList: [Position]) {
        XCTAssertEqual(positionList.count, 2)

        let mutualFund = positionList[0]
        XCTAssertEqual(mutualFund.asset.type, .mutualFund)
        XCTAssertEqual(mutualFund.asset.symbol, "MFC")

        let currency = positionList[1]
        XCTAssertEqual(currency.asset.type, .currency)
        XCTAssertEqual(currency.asset.symbol, "USD")
    }

}
