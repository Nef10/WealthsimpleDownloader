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

    private static var baseUrl: URLComponents { URLConfiguration.shared.urlComponents(for: "transactions")! }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
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
            throw TransactionError.missingResultParamenter(json: json)
        }
        guard let processDate = Self.dateFormatter.date(from: processDateString),
              let effectiveDate = Self.dateFormatter.date(from: effectiveDateString),
              let type = TransactionType(rawValue: typeString.camelCase),
              object == "transaction" else {
            throw TransactionError.invalidResultParamenter(json: json)
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

    static func getTransactions(token: Token, account: Account, startDate: Date?, completion: @escaping (Result<[Transaction], TransactionError>) -> Void) {
        var url = baseUrl
        url.queryItems = [
            URLQueryItem(name: "account_id", value: account.id),
            URLQueryItem(name: "limit", value: "250")
        ]
        if let date = startDate {
            url.queryItems?.append(URLQueryItem(name: "effective_date_start", value: dateFormatter.string(from: date)))
            url.queryItems?.append(URLQueryItem(name: "process_date_start", value: dateFormatter.string(from: date)))
        }
        url.queryItems?.append(URLQueryItem(name: "effective_date_end", value: dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)))
        var request = URLRequest(url: url.url!)
        let session = URLSession.shared
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        token.authenticateRequest(request) { request in
            let task = session.dataTask(with: request) { data, response, error in
                handleResponse(data: data, response: response, error: error, completion: completion)
            }
            task.resume()
        }
    }

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Transaction], TransactionError>) -> Void) {
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
        do {
            completion(try parse(data: data))
        } catch {
            completion(.failure(TransactionError.invalidJson(error: error.localizedDescription)))
            return
        }
    }

    private static func parse(data: Data) throws -> Result<[Transaction], TransactionError> {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(TransactionError.invalidJsonType(json: try JSONSerialization.jsonObject(with: data, options: [])))
        }
        do {
            guard let results = json["results"] as? [[String: Any]], let object = json["object"] as? String else {
                throw TransactionError.missingResultParamenter(json: json)
            }
            guard object == "transaction" else {
                throw TransactionError.invalidResultParamenter(json: json)
            }
            var transactions = [Transaction]()
            for result in results {
                transactions.append(try Self(json: result))
            }
            return .success(transactions)
        } catch {
            return .failure(error as! TransactionError) // swiftlint:disable:this force_cast
        }
    }

}
