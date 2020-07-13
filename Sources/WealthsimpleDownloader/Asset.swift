//
//  Asset.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation

/// An asset, like a stock or a currency
public struct Asset {

    /// Errors which can happen when retrieving an Asset
    public enum AssetError: Error {
        case missingResultParamenter(json: [String: Any])
        case invalidResultParamenter(json: [String: Any])
    }

    /// Type of the asset
    public enum AssetType: String {
        case currency
        case equity
        case mutualFund = "mutual_fund"
        case bond
        case exchangeTradedFund = "exchange_traded_fund"
    }

    /// Symbol of the asset, e.g. currency or ticker symbol
    public let symbol: String
    /// Full name of the asset
    public let name: String
    /// Currency the asset is held in
    public let currency: String
    /// Type of the asset, e.g. currency or ETF
    public let type: AssetType

    let id: String

    init(json: [String: Any]) throws {
        guard let id = json["security_id"] as? String,
              let symbol = json["symbol"] as? String,
              let currency = json["currency"] as? String,
              let name = json["name"] as? String,
              let typeString = json["type"] as? String else {
            throw AssetError.missingResultParamenter(json: json)
        }
        guard let type = AssetType(rawValue: typeString) else {
            throw AssetError.invalidResultParamenter(json: json)
        }
        self.id = id
        self.symbol = symbol
        self.currency = currency
        self.name = name
        self.type = type
    }
}
