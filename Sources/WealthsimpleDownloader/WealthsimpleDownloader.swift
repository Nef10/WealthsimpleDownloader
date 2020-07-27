//
//  WealthsimpleDownloader.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation

/// Protocol to save API tokens
///
/// Can for example be implemented using Keychain on Apple devices
public protocol CredentialStorage {

    /// Save a value to the store
    /// - Parameters:
    ///   - value: value
    ///   - key: key to retrieve in later
    func save(_ value: String, for key: String)

    /// Retrieve a value
    /// - Parameter key: key under which the value was stored
    ///
    /// - Returns: The saved value or nil if no value was found
    func read(_ key: String) -> String?

}

/// Main entry point for the library
public final class WealthsimpleDownloader {

    /// Callback which is called in case the user needs to authenticate. Needs to return username, password, and one time password
    public typealias AuthenticationCallback = (@escaping (String, String, String) -> Void) -> Void

    private let authenticationCallback: AuthenticationCallback
    private let credentialStorage: CredentialStorage
    private var token: Token?

    /// Creates the Downloader instance
    ///
    /// After creating, first call the authenticate method.
    ///
    /// - Parameters:
    ///   - authenticationCallback: Callback which is called in case the user needs to authenticate.
    ///     Needs to return username, password, and one time password. Might be called during any call.
    ///   - credentialStorage: A CredentialStore to save API tokens to. Implementation can be empty,
    ///     in this case the authenticationCallback will be called every time and not only when the refresh token expired
    public init(authenticationCallback: @escaping AuthenticationCallback, credentialStorage: CredentialStorage) {
        self.authenticationCallback = authenticationCallback
        self.credentialStorage = credentialStorage
    }

    /// Authneticates against the API. Call before calling any other method.
    /// - Parameter completion: Get an error in case soemthing went wrong, otherwise nil
    public func authenticate(completion: @escaping (Error?) -> Void) {
        guard token == nil else {
            completion(nil)
            return
        }
        token = Token.getToken(from: credentialStorage)
        if let token = token {
            token.testIfValid {
                if $0 {
                    completion(nil)
                    return
                } else {
                    self.token = nil
                    self.getNewToken(completion: completion)
                    return
                }
            }
        } else {
            getNewToken(completion: completion)
        }
    }

    /// Get all Accounts the user has access to
    /// - Parameter completion: Result with an array of `Account`s or an `Account.AccountError`
    public func getAccounts(completion: @escaping (Result<[Account], Account.AccountError>) -> Void) {
        guard let token = token else {
            completion(.failure(.tokenError(.noToken)))
            return
        }
        Account.getAccounts(token: token) {
            if case let .failure(error) = $0 {
                if case .tokenError = error {
                    self.token = nil
                }
            }
            completion($0)
        }
    }

    /// Get all `Position`s from one `Account`
    /// - Parameters:
    ///   - account: Account to retreive positions for
    ///   - completion: Result with an array of `Position`s or an `Position.PositionError`
    public func getPositions(in account: Account, completion: @escaping (Result<[Position], Position.PositionError>) -> Void) {
        guard let token = token else {
            completion(.failure(.tokenError(.noToken)))
            return
        }
        Position.getPositions(token: token, account: account) {
            if case let .failure(error) = $0 {
                if case .tokenError = error {
                    self.token = nil
                }
            }
            completion($0)
        }
    }

    /// Get all `Transactions`s from one `Account`
    /// - Parameters:
    ///   - account: Account to retreive transactions from
    ///   - completion: Result with an array of `Transactions`s or an `Transactions.TransactionsError`
    public func getTransactions(in account: Account, completion: @escaping (Result<[Transaction], Transaction.TransactionError>) -> Void) {
        guard let token = token else {
            completion(.failure(.tokenError(.noToken)))
            return
        }
        Transaction.getTransactions(token: token, account: account) {
            if case let .failure(error) = $0 {
                if case .tokenError = error {
                    self.token = nil
                }
            }
            completion($0)
        }
    }

    private func getNewToken(completion: @escaping (Error?) -> Void) {
        authenticationCallback { username, password, otp in
            Token.getToken(username: username, password: password, otp: otp, credentialStorage: self.credentialStorage) {
                switch $0 {
                case let .failure(error):
                    completion(error)
                case let .success(token):
                    self.token = token
                    completion(nil)
                }
            }
        }
    }

}
