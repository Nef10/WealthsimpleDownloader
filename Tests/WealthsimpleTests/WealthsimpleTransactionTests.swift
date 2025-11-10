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

final class WealthsimpleTransactionTests: DownloaderTestCase { // swiftlint:disable:this type_body_length

    private struct TestAccount: Account {
        let id: String
        let accountType: AccountType
        let currency: String
        let number: String
    }

    private static let startDate = Date(timeIntervalSince1970: 0)

    private static let transactionJSON: [String: Any] = [
        "id": "transaction-123",
        "account_id": "account-456",
        "type": "buy",
        "description": "Buy AAPL",
        "symbol": "AAPL",
        "quantity": "10.0",
        "market_price": ["amount": "150.00", "currency": "USD"],
        "market_value": ["amount": "1500.00", "currency": "USD"],
        "net_cash": ["amount": "-1500.00", "currency": "USD"],
        "process_date": "2023-01-15",
        "effective_date": "2023-01-16",
        "fx_rate": "1.0",
        "object": "transaction"
    ]

    // MARK: - Helper Methods

    private func createValidToken() throws -> Token {
        let expectation = XCTestExpectation(description: "createValidToken completion")
        var resultToken: Token?

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "valid_access_token3"
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
        TestAccount(id: "test-account-123", accountType: .tfsa, currency: "CAD", number: "12345")
    }

    private func setupMockForSuccess(transactions: [[String: Any]], expectation: XCTestExpectation) {
        MockURLProtocol.transactionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token3")
            XCTAssertTrue(url.query()?.contains("effective_date_start") ?? false)
            XCTAssertTrue(url.query()?.contains("process_date_start") ?? false)

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

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
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
            line: line
        )
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

        let transactionJSON = Self.transactionJSON
        setupMockForSuccess(transactions: [transactionJSON], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
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

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
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

    func testGetTransactionsMultipleTransactionTypes() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        var buyTransaction = Self.transactionJSON
        buyTransaction["type"] = "buy"
        buyTransaction["id"] = "buy-transaction"

        var dividendTransaction = Self.transactionJSON
        dividendTransaction["type"] = "dividend"
        dividendTransaction["id"] = "dividend-transaction"

        var feeTransaction = Self.transactionJSON
        feeTransaction["type"] = "custodian_fee"
        feeTransaction["id"] = "fee-transaction"

        var paymentTransaction = Self.transactionJSON
        paymentTransaction["type"] = "wealthsimple_payments_transfer_in"
        paymentTransaction["id"] = "payment-transaction"

        setupMockForSuccess(transactions: [buyTransaction, dividendTransaction, feeTransaction, paymentTransaction], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 4)
                XCTAssertEqual(transactions[0].transactionType, .buy)
                XCTAssertEqual(transactions[1].transactionType, .dividend)
                XCTAssertEqual(transactions[2].transactionType, .custodianFee)
                XCTAssertEqual(transactions[3].transactionType, .paymentTransferIn)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetTransactionsAppendsStartDateQueryItems() throws {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDateString = dateFormatter.string(from: startDate)

        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        MockURLProtocol.transactionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token3")
            XCTAssert(url.query()?.contains("effective_date_start=\(expectedDateString)") ?? false)
            XCTAssert(url.query()?.contains("process_date_start=\(expectedDateString)") ?? false)

            let jsonResponse = [
                "object": "transaction",
                "results": [Self.transactionJSON]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: startDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 1)
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
            }, expectedError: TransactionError.httpError(error: "The operation couldn’t be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#endif

    func testGetTransactionsEmptyData() throws {
        try testTransactionsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data()
            ), expectedError: TransactionError.invalidJson(json: Data())
        )
    }

    func testGetTransactionsWrongResponseType() throws {
        try testTransactionsFailure(response: (
            URLResponse(url: URL(string: "http://test.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
            Data()
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
        try testJSONParsingFailure(jsonData: data, expectedError: TransactionError.invalidJson(json: data))
    }

    func testGetTransactionsInvalidJSONType() throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            XCTFail("Failed to create test JSON data")
            return
        }
        try testJSONParsingFailure(jsonData: jsonData, expectedError: TransactionError.invalidJson(json: jsonData))
    }

    func testGetTransactionsMissingResults() throws {
        let json = ["object": "transaction"]
        try testJSONParsingFailure(
            jsonObject: json,
            expectedError: TransactionError.missingResultParameter(json: json)
        )
    }

    func testGetTransactionsInvalidObject() throws {
        let json: [String: Any] = ["object": "not_transaction", "results": []]
        try testJSONParsingFailure(
            jsonObject: json,
            expectedError: TransactionError.invalidResultParameter(json: json)
        )
    }

    func testTransactionMissingId() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "id")
        try testJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    func testTransactionMissingProcessDate() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "process_date")
        try testJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    func testTransactionMissingEffectiveDate() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "effective_date")
        try testJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidProcessDate() throws {
        var transaction = Self.transactionJSON
        transaction["process_date"] = "invalid-date"
        try testJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidEffectiveDate() throws {
        var transaction = Self.transactionJSON
        transaction["effective_date"] = "invalid-date"
        try testJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidType() throws {
        var transaction = Self.transactionJSON
        transaction["type"] = "invalid_transaction_type"
        try testJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidObject() throws {
        var transaction = Self.transactionJSON
        transaction["object"] = "not_transaction"
        try testJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

}
