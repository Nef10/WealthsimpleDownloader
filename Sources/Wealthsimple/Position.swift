//
//  Position.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A Position, like certain amount of a stock or a currency held in an account
public struct Position {

    /// Errors which can happen when retrieving a Position
    public enum PositionError: Error {
        /// When no data is received from the HTTP request
        case noDataReceived
        /// When an HTTP error occurs
        case httpError(error: String)
        /// When the received data is not valid JSON
        case invalidJson(error: String)
        /// When the received JSON does not have the right type
        case invalidJsonType(json: Any)
        /// When the received JSON does not have all expected values
        case missingResultParamenter(json: [String: Any])
        /// When the received JSON does have an unexpected value
        case invalidResultParamenter(json: [String: Any])
        /// An error with the assets occured
        case assetError(_ error: Asset.AssetError)
        /// An error with the token occured
        case tokenError(_ error: TokenError)
    }

    private static let baseUrl = URLComponents(string: "https://api.production.wealthsimple.com/v1/positions")!

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Wealthsimple identifier of the account in which this position is held
    public let accountId: String
    /// Asset which is held
    public let asset: Asset
    /// Number of units of the asset held
    public let quantity: String
    /// Price per pice of the asset on `priceDate`
    public let priceAmount: String
    /// Currency of the price
    public let priceCurrency: String
    /// Date of the positon
    public let positionDate: Date

    private init(json: [String: Any]) throws {
        guard let quantity = json["quantity"] as? String,
              let accountId = json["account_id"] as? String,
              let assetDict = json["asset"] as? [String: Any],
              let price = json["market_price"] as? [String: Any],
              let dateString = json["position_date"] as? String,
              let priceAmount = price["amount"] as? String,
              let priceCurrency = price["currency"] as? String,
              let object = json["object"] as? String
        else {
            throw PositionError.missingResultParamenter(json: json)
        }
        guard let date = Self.dateFormatter.date(from: dateString),
              object == "position" else {
            throw PositionError.invalidResultParamenter(json: json)
        }
        do {
            self.asset = try Asset(json: assetDict)
        } catch {
            throw PositionError.assetError(error as! Asset.AssetError) // swiftlint:disable:this force_cast
        }
        self.accountId = accountId
        self.quantity = quantity
        self.priceAmount = priceAmount
        self.priceCurrency = priceCurrency
        self.positionDate = date
    }

    static func getPositions(token: Token, account: Account, date: Date?, completion: @escaping (Result<[Position], PositionError>) -> Void) {
        var url = baseUrl
        url.queryItems = [
            URLQueryItem(name: "account_id", value: account.id),
            URLQueryItem(name: "limit", value: "250")
        ]
        if let date = date {
            url.queryItems?.append(URLQueryItem(name: "date", value: dateFormatter.string(from: date)))
        }
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

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Position], PositionError>) -> Void) {
        guard let data = data else {
            if let error = error {
                completion(.failure(PositionError.httpError(error: error.localizedDescription)))
            } else {
                completion(.failure(PositionError.noDataReceived))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(PositionError.httpError(error: "No HTTPURLResponse")))
            return
        }
        guard httpResponse.statusCode == 200 else {
            completion(.failure(PositionError.httpError(error: "Status code \(httpResponse.statusCode)")))
            return
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                completion(.failure(PositionError.invalidJsonType(json: try JSONSerialization.jsonObject(with: data, options: []))))
                return
            }
            do {
                guard let results = json["results"] as? [[String: Any]], let object = json["object"] as? String else {
                    throw PositionError.missingResultParamenter(json: json)
                }
                guard object == "position" else {
                    throw PositionError.invalidResultParamenter(json: json)
                }
                var positions = [Position]()
                for result in results {
                    positions.append(try Position(json: result))
                }
                completion(.success(positions))
            } catch {
                completion(.failure(error as! PositionError)) // swiftlint:disable:this force_cast
            }
        } catch {
            completion(.failure(PositionError.invalidJson(error: error.localizedDescription)))
            return
        }
    }

}
