//
//  Account.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation
 #if canImport(FoundationNetworking)
 import FoundationNetworking
 #endif

/// An Account at Wealthsimple
public struct Account {

    /// Errors which can happen when retrieving an Account
    public enum AccountError: Error {
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
        /// An error with the token occured
        case tokenError(_ error: TokenError)
    }

    /// Type of the account
    ///
    /// Note: Currently only Canadian Accounts are supported
    public enum AccountType: String {
        /// Tax free savings account (CA)
        case tfsa = "ca_tfsa"
        /// Cash (chequing) account (CA)
        case chequing = "ca_cash"
        /// Registered Retirement Savings Plan (CA)
        case rrsp = "ca_rrsp"
        /// Non-registered account (CA)
        case nonRegistered = "ca_non_registered"
        /// Non-registered crypto currency account (CA)
        case nonRegisteredCrypto = "ca_non_registered_crypto"
        /// Locked-in retirement account (CA)
        case lira = "ca_lira"
        /// Joint account (CA)
        case joint = "ca_joint"
        /// Registered Retirement Income Fund (CA)
        case rrif = "ca_rrif"
        /// Life Income Fund (CA)
        case lif = "ca_lif"
    }

    private static let url = URL(string: "https://api.production.wealthsimple.com/v1/accounts")!

    /// Type of the account
    public let accountType: AccountType
    /// Operating currency of the account
    public let currency: String
    /// Wealthsimple id for the account
    public let id: String

    private init(json: [String: Any]) throws {
        guard let id = json["id"] as? String,
              let typeString = json["type"] as? String,
              let object = json["object"] as? String,
              let currency = json["base_currency"] as? String else {
            throw AccountError.missingResultParamenter(json: json)
        }
        guard let type = AccountType(rawValue: typeString), object == "account" else {
            throw AccountError.invalidResultParamenter(json: json)
        }
        self.id = id
        self.accountType = type
        self.currency = currency
    }

    static func getAccounts(token: Token, completion: @escaping (Result<[Account], AccountError>) -> Void) {
        var request = URLRequest(url: url)
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

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Account], AccountError>) -> Void) {
        guard let data = data else {
            if let error = error {
                completion(.failure(AccountError.httpError(error: error.localizedDescription)))
            } else {
                completion(.failure(AccountError.noDataReceived))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(AccountError.httpError(error: "No HTTPURLResponse")))
            return
        }
        guard httpResponse.statusCode == 200 else {
            completion(.failure(AccountError.httpError(error: "Status code \(httpResponse.statusCode)")))
            return
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                completion(.failure(AccountError.invalidJsonType(json: try JSONSerialization.jsonObject(with: data, options: []))))
                return
            }
            do {
                guard let results = json["results"] as? [[String: Any]], let object = json["object"] as? String else {
                    throw AccountError.missingResultParamenter(json: json)
                }
                guard object == "account" else {
                    throw AccountError.invalidResultParamenter(json: json)
                }
                var accounts = [Account]()
                for result in results {
                    accounts.append(try Account(json: result))
                }
                completion(.success(accounts))
            } catch {
                completion(.failure(error as! AccountError)) // swiftlint:disable:this force_cast
            }
        } catch {
            completion(.failure(AccountError.invalidJson(error: error.localizedDescription)))
            return
        }
    }
}
