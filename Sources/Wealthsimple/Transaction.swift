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

/// A Transaction, like buying or selling stock
public struct Transaction {

    /// Type for the transaction, e.g. buying or selling
    public enum TransactionType: String {
        /// buying a Stock, ETF, ...
        case buy
        /// depositing cash in the account
        case contribution
        /// receiving a dividend
        case dividend
        /// custodian fee
        case custodianFee = "custodian_fee"
        /// deposit
        case deposit
        /// fee
        case fee
        /// forex
        case forex
        /// grant
        case grant
        /// home buyers plan
        case homeBuyersPlan = "home_buyers_plan"
        /// hst
        case hst
        /// charged tnterest
        case chargedInterest = "charged_interest"
        /// journal
        case journal
        /// non resident withholding tax
        case nonResidentWithholdingTax = "non resident withholding tax"
        /// redemption
        case redemption
        /// risk exposure fee
        case riskExposureFee = "risk_exposure_fee"
        /// refund
        case refund
        /// reimbursement
        case reimbursement
        /// sell
        case sell
        /// stock distribution
        case stockDistribution = "stock_distribution"
        /// stock dividend
        case stockDividend = "stock_dividend"
        /// transfer in
        case transferIn = "transfer in"
        /// transfer out
        case transferOut = "transfer out"
        /// withholding tax
        case withholdingTax = "withholding_tax"
        /// withdrawal
        case withdrawal
        /// Wealthsimple Payments Transfer in
        case paymentTransferIn = "wealthsimple payments transfer in"
        /// Weathsimple Payments Transfer Out
        case paymentTransferOut = "wealthsimple payments transfer out"
        /// Referral Bonus
        case referralBonus = "referral bonus"
        /// Interest
        case interest
    }

    private static let baseUrl = URLComponents(string: "https://api.production.wealthsimple.com/v1/transactions")!

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Wealthsimples identifier of this transaction
    public let id: String
    /// Wealthsimple identifier of the account in which this transaction happend
    public let accountId: String
    /// type of the transaction, like buy or sell
    public let transactionType: TransactionType
    /// description of the transaction
    public let description: String
    /// symbol of the asset which is brought, sold, ...
    public let symbol: String
    /// Number of units of the asset brought, sold, ...
    public let quantity: String
    /// market pice of the asset
    public let marketPriceAmount: String
    /// Currency of the market price
    public let marketPriceCurrency: String
    /// market value of the assets
    public let marketValueAmount: String
    /// Currency of the market value
    public let marketValueCurrency: String
    /// Net chash change in the account
    public let netCashAmount: String
    /// Currency of the net cash change
    public let netCashCurrency: String
    /// Foreign exchange rate applied
    public let fxRate: String
    /// Date when the trade was settled
    public let effectiveDate: Date
    /// Date when the trade was processed
    public let processDate: Date

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
              let type = TransactionType(rawValue: typeString.lowercased()),
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
        token.authenticateRequest(request) {
            switch $0 {
            case let .failure(error):
                completion(.failure(.tokenError(error)))
            case let .success(request):
                let task = session.dataTask(with: request) { data, response, error in
                    handleResponse(data: data, response: response, error: error, completion: completion)
                }
                task.resume()
            }
        }
    }

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Transaction], TransactionError>) -> Void) {
        guard let data = data else {
            if let error = error {
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
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                completion(.failure(TransactionError.invalidJsonType(json: try JSONSerialization.jsonObject(with: data, options: []))))
                return
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
                    transactions.append(try Transaction(json: result))
                }
                completion(.success(transactions))
            } catch {
                completion(.failure(error as! TransactionError)) // swiftlint:disable:this force_cast
            }
        } catch {
            completion(.failure(TransactionError.invalidJson(error: error.localizedDescription)))
            return
        }
    }

}
