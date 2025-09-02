// swiftlint:disable file_length
//
//  WealthsimpleTransactionTests.swift
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

final class WealthsimpleTransactionTests: XCTestCase { // swiftlint:disable:this type_body_length

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

        mockCredentialStorage.storage["accessToken"] = "valid_access_token1"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            resultToken = token
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        guard let resultToken else {
            XCTFail("Did not get valid token")
            throw TokenError.noToken
        }
        return resultToken
    }

    private func createValidAccount() -> Account {
        struct TestAccount: Account {
            let id: String
            let accountType: AccountType
            let currency: String
            let number: String
        }
        return TestAccount(id: "test-account-123", accountType: .tfsa, currency: "CAD", number: "12345")
    }

    private func createValidTransactionJSON() -> [String: Any] {
        [
            "id": "transaction-123",
            "account_id": "account-456",
            "type": "buy",
            "description": "Buy AAPL",
            "symbol": "AAPL",
            "quantity": "10.0",
            "market_price": [
                "amount": "150.00",
                "currency": "USD"
            ],
            "market_value": [
                "amount": "1500.00",
                "currency": "USD"
            ],
            "net_cash": [
                "amount": "-1500.00",
                "currency": "USD"
            ],
            "process_date": "2023-01-15",
            "effective_date": "2023-01-16",
            "fx_rate": "1.0",
            "object": "transaction"
        ]
    }

    private func setupMockForSuccess(transactions: [[String: Any]], expectation: XCTestExpectation) {
        MockURLProtocol.transactionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token1")

            let jsonResponse = [
                "object": "transaction",
                "results": transactions
            ]
            expectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
    }

    private func testTransactionsFailure(response: (URLResponse, Data), expectedError: TransactionError, file: StaticString = #file, line: UInt = #line) throws {
        let mockExpectation = XCTestExpectation(description: "mock server called")

        try testTransactionsFailure(
            response: { _, _ in
                mockExpectation.fulfill()
                return response
            },
            expectedError: expectedError,
            file: file,
            line: line
        )

        wait(for: [mockExpectation], timeout: 10.0)
    }

    private func testTransactionsFailure(
        response: @escaping ((URL, URLRequest) throws -> (URLResponse, Data)),
        expectedError: TransactionError,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")

        MockURLProtocol.transactionsRequestHandler = response

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: nil) { result in
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

    private func testJSONParsingFailure(jsonData: Data, expectedError: TransactionError, file: StaticString = #file, line: UInt = #line) throws {
        try testTransactionsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                jsonData
            ),
            expectedError: expectedError,
            file: file,
            line: line)
    }

    private func testJSONParsingFailure(jsonObject: [String: Any], expectedError: TransactionError, file: StaticString = #file, line: UInt = #line) throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            XCTFail("Failed to create JSON data", file: file, line: line)
            return
        }
        try testJSONParsingFailure(jsonData: jsonData, expectedError: expectedError, file: file, line: line)
    }

    // MARK: - Successful Tests

    // swiftlint:disable:next function_body_length
    func testGetTransactionsSuccess() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let transactionJSON = createValidTransactionJSON()
        setupMockForSuccess(transactions: [transactionJSON], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: nil) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 1)

                let transaction = transactions[0]
                XCTAssertEqual(transaction.id, "transaction-123")
                XCTAssertEqual(transaction.accountId, "account-456")
                XCTAssertEqual(transaction.transactionType, .buy)
                XCTAssertEqual(transaction.description, "Buy AAPL")
                XCTAssertEqual(transaction.symbol, "AAPL")
                XCTAssertEqual(transaction.quantity, "10.0")
                XCTAssertEqual(transaction.marketPriceAmount, "150.00")
                XCTAssertEqual(transaction.marketPriceCurrency, "USD")
                XCTAssertEqual(transaction.marketValueAmount, "1500.00")
                XCTAssertEqual(transaction.marketValueCurrency, "USD")
                XCTAssertEqual(transaction.netCashAmount, "-1500.00")
                XCTAssertEqual(transaction.netCashCurrency, "USD")
                XCTAssertEqual(transaction.fxRate, "1.0")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                XCTAssertEqual(transaction.processDate, dateFormatter.date(from: "2023-01-15"))
                XCTAssertEqual(transaction.effectiveDate, dateFormatter.date(from: "2023-01-16"))

            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetTransactionsEmptyResults() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        setupMockForSuccess(transactions: [], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: nil) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 0)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // swiftlint:disable:next function_body_length
    func testGetTransactionsMultipleTransactionTypes() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        var buyTransaction = createValidTransactionJSON()
        buyTransaction["type"] = "buy"
        buyTransaction["id"] = "buy-transaction"

        var sellTransaction = createValidTransactionJSON()
        sellTransaction["type"] = "sell"
        sellTransaction["id"] = "sell-transaction"

        var dividendTransaction = createValidTransactionJSON()
        dividendTransaction["type"] = "dividend"
        dividendTransaction["id"] = "dividend-transaction"

        // Test some transaction types that use camelCase conversion
        var feeTransaction = createValidTransactionJSON()
        feeTransaction["type"] = "custodian_fee"
        feeTransaction["id"] = "fee-transaction"

        var paymentTransaction = createValidTransactionJSON()
        paymentTransaction["type"] = "wealthsimple_payments_transfer_in"
        paymentTransaction["id"] = "payment-transaction"

        setupMockForSuccess(transactions: [buyTransaction, sellTransaction, dividendTransaction, feeTransaction, paymentTransaction], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: nil) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 5)
                XCTAssertEqual(transactions[0].transactionType, .buy)
                XCTAssertEqual(transactions[1].transactionType, .sell)
                XCTAssertEqual(transactions[2].transactionType, .dividend)
                XCTAssertEqual(transactions[3].transactionType, .custodianFee)
                XCTAssertEqual(transactions[4].transactionType, .paymentTransferIn)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - Network Error Tests

#if canImport(FoundationNetworking)
    func testGetTransactionsNetworkFailure() throws {
        try testTransactionsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: TransactionError.httpError(error: "The operation could not be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#else
    func testGetTransactionsNetworkFailure() throws {
        try testTransactionsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: TransactionError.httpError(error: "The operation couldn't be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#endif

    func testGetTransactionsInvalidJSONEmptyData() throws {
        try testTransactionsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data()
            ), expectedError: TransactionError.invalidJson(error: "The operation could not be completed. The data is not in the correct format.")
        )
    }

    func testGetTransactionsWrongResponseType() throws {
        try testTransactionsFailure(response: (
            URLResponse(url: URL(string: "http://test.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
            Data("test".utf8)
        ), expectedError: TransactionError.httpError(error: "No HTTPURLResponse"))
    }

    func testGetTransactionsHTTPError() throws {
        try testTransactionsFailure(response: (
            HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
            Data()
        ), expectedError: TransactionError.httpError(error: "Status code 401"))
    }

    // MARK: - JSON Parsing Error Tests

    func testGetTransactionsInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testJSONParsingFailure(
            jsonData: data,
            expectedError: TransactionError.invalidJson(error: "The operation could not be completed. The data is not in the correct format.")
        )
    }

    func testGetTransactionsInvalidJSONType() throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            XCTFail("Failed to create test JSON data")
            return
        }
        try testJSONParsingFailure(
            jsonData: jsonData,
            expectedError: TransactionError.invalidJsonType(json: ["not", "a", "dictionary"])
        )
    }

    func testGetTransactionsMissingResults() throws {
        try testJSONParsingFailure(jsonObject: ["object": "transaction"], expectedError: TransactionError.missingResultParamenter(json: ["object": "transaction"]))
    }

    func testGetTransactionsInvalidObject() throws {
        try testJSONParsingFailure(
            jsonObject: ["object": "not_transaction", "results": []],
            expectedError: TransactionError.invalidResultParamenter(json: ["object": "not_transaction", "results": []])
        )
    }

    // MARK: - Transaction JSON Parsing Error Tests

    func testTransactionMissingId() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "id")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingAccountId() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "account_id")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingType() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "type")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingDescription() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "description")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingSymbol() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "symbol")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingQuantity() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "quantity")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingMarketPrice() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "market_price")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingMarketValue() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "market_value")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingNetCash() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "net_cash")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingProcessDate() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "process_date")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingEffectiveDate() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "effective_date")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingFxRate() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "fx_rate")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingObject() throws {
        var transaction = createValidTransactionJSON()
        transaction.removeValue(forKey: "object")
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingMarketPriceAmount() throws {
        var transaction = createValidTransactionJSON()
        transaction["market_price"] = ["currency": "USD"]
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingMarketPriceCurrency() throws {
        var transaction = createValidTransactionJSON()
        transaction["market_price"] = ["amount": "150.00"]
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingMarketValueAmount() throws {
        var transaction = createValidTransactionJSON()
        transaction["market_value"] = ["currency": "USD"]
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingMarketValueCurrency() throws {
        var transaction = createValidTransactionJSON()
        transaction["market_value"] = ["amount": "1500.00"]
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingNetCashAmount() throws {
        var transaction = createValidTransactionJSON()
        transaction["net_cash"] = ["currency": "USD"]
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    func testTransactionMissingNetCashCurrency() throws {
        var transaction = createValidTransactionJSON()
        transaction["net_cash"] = ["amount": "-1500.00"]
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.missingResultParamenter(json: transaction))
    }

    // MARK: - Invalid Value Tests

    func testTransactionInvalidProcessDate() throws {
        var transaction = createValidTransactionJSON()
        transaction["process_date"] = "invalid-date"
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.invalidResultParamenter(json: transaction))
    }

    func testTransactionInvalidEffectiveDate() throws {
        var transaction = createValidTransactionJSON()
        transaction["effective_date"] = "invalid-date"
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.invalidResultParamenter(json: transaction))
    }

    func testTransactionInvalidType() throws {
        var transaction = createValidTransactionJSON()
        transaction["type"] = "invalid_transaction_type"
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.invalidResultParamenter(json: transaction))
    }

    func testTransactionInvalidObject() throws {
        var transaction = createValidTransactionJSON()
        transaction["object"] = "not_transaction"
        try testJSONParsingFailure(jsonObject: [
            "object": "transaction",
            "results": [transaction]
        ], expectedError: TransactionError.invalidResultParamenter(json: transaction))
    }
}
