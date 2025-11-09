//
//  Transaction.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Errors which can happen when retrieving a Transaction
public enum TransactionError: Error, Equatable {
    /// When no data is received from the HTTP request
    case noDataReceived
    /// When an HTTP error occurs
    case httpError(error: String)
    /// When the received data is not valid JSON
    case invalidJson(json: Data)
    /// When the received JSON does not have all expected values
    case missingResultParameter(json: String)
    /// When the received JSON does have an unexpected value
    case invalidResultParameter(json: String)
    /// An error with the token occured
    case tokenError(_ error: TokenError)
    /// Invalid Parameter
    case invalidParameter
}

/// Type for the transaction, e.g. buying or selling
public enum TransactionType: String {
    /// buying a Stock, ETF, ...
    case buy
    /// depositing cash in a registered account
    case contribution
    /// receiving a cash dividend
    case dividend
    /// custodian fee
    case custodianFee
    /// depositing cash in an unregistered account
    case deposit
    /// wealthsimple management fee
    case fee
    /// forex
    case forex
    /// grant
    case grant
    /// home buyers plan
    case homeBuyersPlan
    /// hst
    case hst
    /// charged interest
    case chargedInterest
    /// journal
    case journal
    /// US non resident withholding tax on dividend payments
    case nonResidentWithholdingTax
    /// redemption
    case redemption
    /// risk exposure fee
    case riskExposureFee
    /// refund
    case refund
    /// reimbursements, e.g. ETF Fee Rebates
    case reimbursement
    /// selling a Stock, ETF, ...
    case sell
    /// stock distribution
    case stockDistribution
    /// stock dividend
    case stockDividend
    /// transfer in
    case transferIn
    /// transfer out
    case transferOut
    /// withholding tax
    case withholdingTax
    /// withdrawal of cash
    case withdrawal
    /// Cash transfer into cash account
    case paymentTransferIn = "wealthsimplePaymentsTransferIn"
    /// Cash withdrawl from cash account
    case paymentTransferOut = "wealthsimplePaymentsTransferOut"
    /// Referral Bonus
    case referralBonus
    /// Interest paid in saving accounts
    case interest
    /// Wealthsimple Cash Card payments
    case paymentSpend = "wealthsimplePaymentsSpend"
    /// Wealthsimple Cash Cashback
    case giveawayBonus
    /// Wealthsimple Cash Cashback
    case cashbackBonus
    /// Online Bill Payment
    case onlineBillPayment
    /// Loaning out stock to a third party
    case stockLoanBorrow = "fPLLoanedSecurities"
    /// Returning stock which was borrowed from a third party
    case stockLoanReturn = "fPLRecalledSecurities"
    /// Manufactured dividend, which is paid out from the third party who borrowed the stock
    case manufacturedDividend
    /// Return of Capital (Adjusted Cost Base entry only)
    case returnOfCapital
    /// Non-cash Distribution (Adjusted Cost Base entry only)
    case nonCashDistribution
    /// Credit Card Purchase
    case purchase
    /// Credit Card Payment
    case payment
}

/// A Transaction, like buying or selling stock
public protocol Transaction {
    /// Wealthsimples identifier of this transaction
    var id: String { get }
    /// Wealthsimple identifier of the account in which this transaction happend
    var accountId: String { get }
    /// type of the transaction, like buy or sell
    var transactionType: TransactionType { get }
    /// description of the transaction
    var description: String { get }
    /// symbol of the asset which is bought, sold, ...
    var symbol: String { get }
    /// Number of units of the asset bought, sold, ...
    var quantity: String { get }
    /// market pice of the asset
    var marketPriceAmount: String { get }
    /// Currency of the market price
    var marketPriceCurrency: String { get }
    /// market value of the assets
    var marketValueAmount: String { get }
    /// Currency of the market value
    var marketValueCurrency: String { get }
    /// Net cash change in the account
    var netCashAmount: String { get }
    /// Currency of the net cash change
    var netCashCurrency: String { get }
    /// Foreign exchange rate applied
    var fxRate: String { get }
    /// Date when the trade was settled
    var effectiveDate: Date { get }
    /// Date when the trade was processed
    var processDate: Date { get }
}

struct WealthsimpleTransaction: Transaction {

    private enum RequestType {
        case graphQL
        case rest
    }

    private enum RequestResult {
        case graphQL([String: Any])
        case rest([Transaction])
    }

    private static var baseUrl: URLComponents { URLConfiguration.shared.urlComponents(for: "transactions")! }

    private static let graphQLQuery = """
        query FetchActivityFeedItems($cursor: Cursor, $condition: ActivityCondition) { \
          activityFeedItems( \
            after: $cursor \
            condition: $condition \
            orderBy: OCCURRED_AT_DESC \
          ) { \
            edges { \
              node { \
                amount \
                amountSign \
                currency \
                externalCanonicalId \
                occurredAt \
                spendMerchant \
                status \
                subType \
                accountId \
              } \
            } \
            pageInfo { \
              hasNextPage \
              endCursor \
            } \
          } \
        }
        """
    private static let graphQLOperation = "FetchActivityFeedItems"

    private static let graphQLQueryDetailsFragment = """
        fragment Activity on CreditCardActivity { \
          originalAmount \
          originalCurrency \
          isForeign \
          foreignExchangeRate \
          settledAt \
        }
        """
    private static let graphQLOperationDetails = "CreditCardActivity"

    private static var dateFormatterREST: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private static var dateFormatterGraphQLRequest: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return dateFormatter
    }()

    private static var dateFormatterGraphQLResult: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"
        return dateFormatter
    }()

    private static var dateFormatterGraphQLResult2: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
        return dateFormatter
    }()

    let id: String
    let accountId: String
    let transactionType: TransactionType
    let description: String
    let symbol: String
    let quantity: String
    let marketPriceAmount: String
    let marketPriceCurrency: String
    let marketValueAmount: String
    let marketValueCurrency: String
    let netCashAmount: String
    let netCashCurrency: String
    let fxRate: String
    let effectiveDate: Date
    let processDate: Date

    // swiftlint:disable:next function_body_length
    private init(json: [String: Any]) throws {
        guard let description = json["description"] as? String,
              let id = json["id"] as? String,
              let accountId = json["account_id"] as? String,
              let typeString = json["type"] as? String,
              let symbol = json["symbol"] as? String,
              let quantity = json["quantity"] as? String,
              let marketPriceDict = json["market_price"] as? [String: Any],
              let marketValueDict = json["market_value"] as? [String: Any],
              let netCashDict = json["net_cash"] as? [String: Any],
              let marketPriceAmount = marketPriceDict["amount"] as? String,
              let marketPriceCurrency = marketPriceDict["currency"] as? String,
              let marketValueAmount = marketValueDict["amount"] as? String,
              let marketValueCurrency = marketValueDict["currency"] as? String,
              let netCashAmount = netCashDict["amount"] as? String,
              let netCashCurrency = netCashDict["currency"] as? String,
              let processDateString = json["process_date"] as? String,
              let effectiveDateString = json["effective_date"] as? String,
              let fxRate = json["fx_rate"] as? String,
              let object = json["object"] as? String
        else {
            throw TransactionError.missingResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        guard let processDate = Self.dateFormatterREST.date(from: processDateString),
              let effectiveDate = Self.dateFormatterREST.date(from: effectiveDateString),
              let type = TransactionType(rawValue: typeString.camelCase),
              object == "transaction" else {
            throw TransactionError.invalidResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        self.id = id
        self.accountId = accountId
        self.description = description
        self.transactionType = type
        self.symbol = symbol
        self.quantity = quantity
        self.marketPriceAmount = marketPriceAmount
        self.marketPriceCurrency = marketPriceCurrency
        self.marketValueAmount = marketValueAmount
        self.marketValueCurrency = marketValueCurrency
        self.netCashAmount = netCashAmount
        self.netCashCurrency = netCashCurrency
        self.fxRate = fxRate
        self.effectiveDate = effectiveDate
        self.processDate = processDate
    }

    private init(graphQL json: [String: Any]) throws {
        guard let quantity = json["amount"] as? String,
              let amountSign = json["amountSign"] as? String,
              let originalAmount = json["originalAmount"] as? String,
              let currency = json["currency"] as? String,
              let originalCurrency = json["originalCurrency"] as? String,
              let id = json["externalCanonicalId"] as? String,
              let occurredAt = json["occurredAt"] as? String,
              let status = json["status"] as? String,
              let subType = json["subType"] as? String,
              let accountId = json["accountId"] as? String,
              let isForeign = json["isForeign"] as? Bool
        else {
            throw TransactionError.missingResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        let description = json["spendMerchant"] as? String ?? ""
        guard let processDate = Self.dateFormatterGraphQLResult.date(from: occurredAt),
              let type = TransactionType(rawValue: subType.lowercased().camelCase) else {
            throw TransactionError.invalidResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        let effectiveDate: Date
        if status == "settled" {
            guard let settledAt = json["settledAt"] as? String, let settlementDate = Self.dateFormatterGraphQLResult2.date(from: settledAt) else {
                throw TransactionError.missingResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            effectiveDate = settlementDate
        } else {
            effectiveDate = processDate
        }
        let foreignExchangeRate: String
        if isForeign {
            guard let fx = json["foreignExchangeRate"] as? String else {
                throw TransactionError.invalidResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            foreignExchangeRate = fx
        } else {
            foreignExchangeRate = "1.0"
        }

        self.id = id
        self.accountId = accountId
        self.description = description
        self.transactionType = type
        self.symbol = originalCurrency
        self.quantity = originalAmount
        self.marketPriceAmount = "1.00"
        self.marketPriceCurrency = currency
        self.marketValueAmount = quantity
        self.marketValueCurrency = currency
        self.netCashAmount = amountSign == "negative" ? "-\(quantity)" : quantity
        self.netCashCurrency = currency
        self.fxRate = foreignExchangeRate
        self.effectiveDate = effectiveDate
        self.processDate = processDate
    }

    static func getTransactions(token: Token, account: Account, startDate: Date, completion: @escaping (Result<[Transaction], TransactionError>) -> Void) {
        getTransactions(token: token, account: account, startDate: startDate, cursor: nil, completion: completion)
    }

    private static func enrichWithFXInfo(edges: [[String : Any]], token: Token) throws -> [[String : Any]] {
        var queryPart1 = "query CreditCardActivity("
        var queryPart2 = ""
        var variables = ""
        var i = 0

        var results = [[String: Any]]()

        for result in edges {
            guard let node = result["node"] as? [String: Any], let id = node["externalCanonicalId"] as? String else {
                throw TransactionError.invalidResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            results.append(node)
            queryPart1 += "$id\(i): ID!, "
            queryPart2 += "a\(i): creditCardActivity(id: $id\(i)) { ...Activity } "
            variables += #" "id\#(i)": "\#(id)", "#
            i += 1
        }
        // remove trailing comma and space
        queryPart1.removeLast(2)
        variables.removeLast(2)
        let query = queryPart1 + ") { " + queryPart2 + "} " + Self.graphQLQueryDetailsFragment
        let requestData: String = #"{"query": "\#(query)", "operationName": "\#(Self.graphQLOperationDetails)", "variables": { \#(variables) } }"#
        guard var request = URLConfiguration.shared.graphQLURLRequest() else {
            throw TransactionError.httpError(error: "Invalid URL")
        }
        let group = DispatchGroup()
        group.enter()
        request.httpBody = Data(requestData.utf8)
        let session = URLSession.shared

        var requestError: Error?
        var fxResult: [String: [String : Any]] = [:]

        token.authenticateRequest(request) { request in
            let task = session.dataTask(with: request) { data, response, error in
                DispatchQueue.global(qos: .userInitiated).async {
                    handleResponse(data: data, response: response, error: error) {
                        switch $0 {
                        case .failure(let failure):
                            requestError = failure
                        case .success(let data):
                            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                                requestError = TransactionError.invalidJson(json: data)
                                return
                            }
                            do {
                                guard let objects = json["data"] as? [String: [String : Any]] else {
                                    throw TransactionError.missingResultParameter(json:
                                        String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
                                }
                                fxResult = objects
                            } catch {
                                requestError = error
                            }
                        }
                    }
                    group.leave()
                }
            }
            task.resume()
        }
        group.wait()
        guard requestError == nil else {
            throw requestError!
        }
        for (key, values) in fxResult {
            guard let index = Int(key.dropFirst()) else {
                throw TransactionError.invalidResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: fxResult, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            results[index] = results[index].merging(values) { (current, _) in current }
        }
        return results
    }
    
    private static func loadNextPage(cursor: String, token: Token, account: Account, startDate: Date) throws -> [Transaction] {
        var nextResult: Result<[Transaction], TransactionError>!
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            getTransactions(token: token, account: account, startDate: startDate, cursor: cursor) {
                nextResult = $0
                group.leave()
            }
        }
        group.wait()
        switch nextResult {
        case .success(let nextTransactions):
            return nextTransactions
        case .failure(let error):
            throw error
        case .none:
            throw TransactionError.noDataReceived
        }
    }
    
    private static func processGraphQLTransactions(json: [String : Any], token: Token, account: Account, startDate: Date, completion: @escaping (Result<[Transaction], TransactionError>) -> Void) {
        do {
            guard let page = json["pageInfo"] as? [String: Any], let edges = json["edges"] as? [[String: Any]], let hasNextPage = page["hasNextPage"] as? Bool, let cursor = page["endCursor"] as? String else {
                throw TransactionError.invalidResultParameter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            
            let transactionInfo = try enrichWithFXInfo(edges: edges, token: token)

            var transactions = [Transaction]()
            for transaction in transactionInfo {
                transactions.append(try Self(graphQL: transaction))
            }
            if hasNextPage {
                let nextTransactions = try loadNextPage(cursor: cursor, token: token, account: account, startDate: startDate)
                transactions.append(contentsOf: nextTransactions)
            }
            completion(.success(transactions))
        } catch {
            completion(.failure(error as! TransactionError))
            return
        }
    }
    
    private static func getTransactions(token: Token, account: Account, startDate: Date, cursor: String? = nil, completion: @escaping (Result<[Transaction], TransactionError>) -> Void) {
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let request: URLRequest
        let type: RequestType
        let completionHandler: (Result<RequestResult, TransactionError>) -> Void = {
            switch $0 {
            case .success(let result):
                switch result {
                case .graphQL(let json):
                    processGraphQLTransactions(json: json, token: token, account: account, startDate: startDate, completion: completion)
                case .rest(let transactions):
                    completion(.success(transactions))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
        if account.accountType == .creditCard {
            type = .graphQL
            do {
                request = try getTransactionsGraphQLRequest(accountID: account.id, startDate: startDate, endDate: endDate, cursor: cursor)
            } catch {
                completion(.failure(error as! TransactionError)) // swiftlint:disable:this force_cast
                return
            }
        } else {
            if cursor != nil {
                completion(.failure(.invalidParameter))
                return
            }
            type = .rest
            request = getTransactionsRESTRequest(accountID: account.id, startDate: startDate, endDate: endDate)
        }
        let session = URLSession.shared
        token.authenticateRequest(request) { request in
            let task = session.dataTask(with: request) { data, response, error in
                DispatchQueue.global(qos: .userInitiated).async {
                    handleResponse(data: data, response: response, error: error) {
                        switch $0 {
                        case .failure(let error):
                            completionHandler(.failure(error))
                        case .success(let data):
                            switch type {
                            case .graphQL:
                                completionHandler(parseGraphQL(data: data))
                            case .rest:
                                completionHandler(parseREST(data: data))
                            }
                        }
                    }
                }
            }
            task.resume()
        }
    }

    private static func getTransactionsGraphQLRequest(accountID: String, startDate: Date, endDate: Date, cursor: String?) throws -> URLRequest {
        guard var request = URLConfiguration.shared.graphQLURLRequest() else {
            throw TransactionError.httpError(error: "Invalid URL")
        }
        let requestData: String = #"{"query": "\#(Self.graphQLQuery)", "operationName": "\#(Self.graphQLOperation)", "variables": { \#(cursor != nil ? #""cursor": "\#(cursor!)","# : "") "condition": { "startDate": "\#(dateFormatterGraphQLRequest.string(from: startDate))", "endDate": "\#(dateFormatterGraphQLRequest.string(from: endDate))", "accountIds": ["\#(accountID)"] } } }"#
        request.httpBody = Data(requestData.utf8)
        return request
    }

    private static func getTransactionsRESTRequest(accountID: String, startDate: Date, endDate: Date) -> URLRequest {
        var url = baseUrl
        url.queryItems = [
            URLQueryItem(name: "account_id", value: accountID),
            URLQueryItem(name: "limit", value: "250"),
            URLQueryItem(name: "effective_date_start", value: dateFormatterREST.string(from: startDate)),
            URLQueryItem(name: "process_date_start", value: dateFormatterREST.string(from: startDate))
        ]
        url.queryItems?.append(URLQueryItem(name: "effective_date_end", value: dateFormatterREST.string(from: endDate)))
        var request = URLRequest(url: url.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<Data, TransactionError>) -> Void) {
        guard let data else {
            if let error {
                completion(.failure(TransactionError.httpError(error: error.localizedDescription)))
            } else {
                completion(.failure(TransactionError.noDataReceived))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(TransactionError.httpError(error: "No HTTPURLResponse")))
            return
        }
        guard httpResponse.statusCode == 200 else {
            completion(.failure(TransactionError.httpError(error: "Status code \(httpResponse.statusCode)")))
            return
        }
        completion(.success(data))
    }

    private static func parseREST(data: Data) -> Result<RequestResult, TransactionError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(TransactionError.invalidJson(json: data))
        }
        do {
            guard let results = json["results"] as? [[String: Any]], let object = json["object"] as? String else {
                throw TransactionError.missingResultParameter(json:
                    String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            guard object == "transaction" else {
                throw TransactionError.invalidResultParameter(json:
                    String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            var transactions = [Transaction]()
            for result in results {
                transactions.append(try Self(json: result))
            }
            return .success(.rest(transactions))
        } catch {
            return .failure(error as! TransactionError) // swiftlint:disable:this force_cast
        }
    }

    private static func parseGraphQL(data: Data) -> Result<RequestResult, TransactionError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(TransactionError.invalidJson(json: data))
        }
        do {
            guard let data = json["data"] as? [String: Any], let results = data["activityFeedItems"] as? [String: Any] else {
                throw TransactionError.missingResultParameter(json:
                    String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            return .success(.graphQL(results))
        } catch {
            return .failure(error as! TransactionError) // swiftlint:disable:this force_cast
        }
    }

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
        case let .missingResultParameter(json):
            return "The server response JSON was missing expected parameters: \(json)"
        case let .invalidResultParameter(json):
            return "The server response JSON contained invalid parameters: \(json)"
        case let .tokenError(error):
            return error.localizedDescription
        case .invalidParameter:
            return "Invalid paramter passed in"
        }
    }
}
