//
//  EnumTests.swift
//
//
//  Created by Copilot on 2025-08-25.
//

import Foundation
@testable import Wealthsimple
import XCTest

final class EnumTests: XCTestCase {

    // MARK: - AssetType Tests
    
    func testAssetTypeRawValues() {
        XCTAssertEqual(AssetType.currency.rawValue, "currency")
        XCTAssertEqual(AssetType.equity.rawValue, "equity")
        XCTAssertEqual(AssetType.mutualFund.rawValue, "mutual_fund")
        XCTAssertEqual(AssetType.bond.rawValue, "bond")
        XCTAssertEqual(AssetType.exchangeTradedFund.rawValue, "exchange_traded_fund")
    }
    
    func testAssetTypeInitFromRawValue() {
        XCTAssertEqual(AssetType(rawValue: "currency"), .currency)
        XCTAssertEqual(AssetType(rawValue: "equity"), .equity)
        XCTAssertEqual(AssetType(rawValue: "mutual_fund"), .mutualFund)
        XCTAssertEqual(AssetType(rawValue: "bond"), .bond)
        XCTAssertEqual(AssetType(rawValue: "exchange_traded_fund"), .exchangeTradedFund)
        
        XCTAssertNil(AssetType(rawValue: "invalid_type"))
        XCTAssertNil(AssetType(rawValue: ""))
        XCTAssertNil(AssetType(rawValue: "EQUITY"))
    }
    
    // MARK: - AccountType Tests
    
    func testAccountTypeRawValues() {
        XCTAssertEqual(AccountType.tfsa.rawValue, "ca_tfsa")
        XCTAssertEqual(AccountType.chequing.rawValue, "ca_cash_msb")
        XCTAssertEqual(AccountType.saving.rawValue, "ca_cash")
        XCTAssertEqual(AccountType.rrsp.rawValue, "ca_rrsp")
        XCTAssertEqual(AccountType.nonRegistered.rawValue, "ca_non_registered")
        XCTAssertEqual(AccountType.nonRegisteredCrypto.rawValue, "ca_non_registered_crypto")
        XCTAssertEqual(AccountType.lira.rawValue, "ca_lira")
        XCTAssertEqual(AccountType.joint.rawValue, "ca_joint")
        XCTAssertEqual(AccountType.rrif.rawValue, "ca_rrif")
        XCTAssertEqual(AccountType.lif.rawValue, "ca_lif")
        XCTAssertEqual(AccountType.creditCard.rawValue, "ca_credit_card")
    }
    
    func testAccountTypeInitFromRawValue() {
        XCTAssertEqual(AccountType(rawValue: "ca_tfsa"), .tfsa)
        XCTAssertEqual(AccountType(rawValue: "ca_cash_msb"), .chequing)
        XCTAssertEqual(AccountType(rawValue: "ca_cash"), .saving)
        XCTAssertEqual(AccountType(rawValue: "ca_rrsp"), .rrsp)
        XCTAssertEqual(AccountType(rawValue: "ca_non_registered"), .nonRegistered)
        XCTAssertEqual(AccountType(rawValue: "ca_non_registered_crypto"), .nonRegisteredCrypto)
        XCTAssertEqual(AccountType(rawValue: "ca_lira"), .lira)
        XCTAssertEqual(AccountType(rawValue: "ca_joint"), .joint)
        XCTAssertEqual(AccountType(rawValue: "ca_rrif"), .rrif)
        XCTAssertEqual(AccountType(rawValue: "ca_lif"), .lif)
        XCTAssertEqual(AccountType(rawValue: "ca_credit_card"), .creditCard)
        
        XCTAssertNil(AccountType(rawValue: "invalid_type"))
        XCTAssertNil(AccountType(rawValue: ""))
        XCTAssertNil(AccountType(rawValue: "tfsa"))  // Without ca_ prefix
        XCTAssertNil(AccountType(rawValue: "CA_TFSA"))  // Wrong case
    }
    
    // MARK: - TransactionType Tests
    
    func testTransactionTypeRawValues() {
        // Test basic transaction types
        XCTAssertEqual(TransactionType.buy.rawValue, "buy")
        XCTAssertEqual(TransactionType.sell.rawValue, "sell")
        XCTAssertEqual(TransactionType.dividend.rawValue, "dividend")
        XCTAssertEqual(TransactionType.deposit.rawValue, "deposit")
        XCTAssertEqual(TransactionType.withdrawal.rawValue, "withdrawal")
        XCTAssertEqual(TransactionType.fee.rawValue, "fee")
        
        // Test complex transaction types with custom raw values
        XCTAssertEqual(TransactionType.paymentTransferIn.rawValue, "wealthsimplePaymentsTransferIn")
        XCTAssertEqual(TransactionType.paymentTransferOut.rawValue, "wealthsimplePaymentsTransferOut")
        XCTAssertEqual(TransactionType.paymentSpend.rawValue, "wealthsimplePaymentsSpend")
        XCTAssertEqual(TransactionType.stockLoanBorrow.rawValue, "fPLLoanedSecurities")
        XCTAssertEqual(TransactionType.stockLoanReturn.rawValue, "fPLRecalledSecurities")
    }
    
    func testTransactionTypeInitFromRawValue() {
        // Test basic types
        XCTAssertEqual(TransactionType(rawValue: "buy"), .buy)
        XCTAssertEqual(TransactionType(rawValue: "sell"), .sell)
        XCTAssertEqual(TransactionType(rawValue: "dividend"), .dividend)
        
        // Test complex types
        XCTAssertEqual(TransactionType(rawValue: "wealthsimplePaymentsTransferIn"), .paymentTransferIn)
        XCTAssertEqual(TransactionType(rawValue: "wealthsimplePaymentsTransferOut"), .paymentTransferOut)
        XCTAssertEqual(TransactionType(rawValue: "wealthsimplePaymentsSpend"), .paymentSpend)
        XCTAssertEqual(TransactionType(rawValue: "fPLLoanedSecurities"), .stockLoanBorrow)
        XCTAssertEqual(TransactionType(rawValue: "fPLRecalledSecurities"), .stockLoanReturn)
        
        // Test invalid values
        XCTAssertNil(TransactionType(rawValue: "invalid_type"))
        XCTAssertNil(TransactionType(rawValue: ""))
        XCTAssertNil(TransactionType(rawValue: "BUY"))  // Wrong case
    }
    
    func testTransactionTypeComprehensiveCoverage() {
        // Test all enum cases to ensure they have valid raw values
        let allCases: [TransactionType] = [
            .buy, .contribution, .dividend, .custodianFee, .deposit, .fee, .forex,
            .grant, .homeBuyersPlan, .hst, .chargedInterest, .journal,
            .nonResidentWithholdingTax, .redemption, .riskExposureFee, .refund,
            .reimbursement, .sell, .stockDistribution, .stockDividend, .transferIn,
            .transferOut, .withholdingTax, .withdrawal, .paymentTransferIn,
            .paymentTransferOut, .referralBonus, .interest, .paymentSpend,
            .giveawayBonus, .cashbackBonus, .onlineBillPayment, .stockLoanBorrow,
            .stockLoanReturn, .manufacturedDividend, .returnOfCapital, .nonCashDistribution
        ]
        
        for transactionType in allCases {
            // Verify raw value is not empty
            XCTAssertFalse(transactionType.rawValue.isEmpty, "Transaction type \(transactionType) has empty raw value")
            
            // Verify round-trip conversion
            XCTAssertEqual(TransactionType(rawValue: transactionType.rawValue), transactionType,
                          "Round-trip conversion failed for \(transactionType)")
        }
    }
    
    // MARK: - Error Types Tests
    
    func testTokenErrorTypes() {
        let errors: [TokenError] = [
            .noToken,
            .invalidJson(error: "test"),
            .invalidJsonType(json: "test"),
            .invalidParameters(parameters: ["key": "value"]),
            .missingResultParamenter(json: ["key": "value"]),
            .httpError(error: "test"),
            .noDataReceived
        ]
        
        // Test that all error types are properly instantiated
        XCTAssertEqual(errors.count, 7)
        for error in errors {
            // Just verify we can access the error - testing that it conforms to Error protocol
            _ = error as Error
        }
    }
    
    func testAssetErrorTypes() {
        let errors: [AssetError] = [
            .missingResultParamenter(json: ["key": "value"]),
            .invalidResultParamenter(json: ["key": "value"])
        ]
        
        // Test that all error types are properly instantiated
        XCTAssertEqual(errors.count, 2)
        for error in errors {
            // Just verify we can access the error - testing that it conforms to Error protocol
            _ = error as Error
        }
    }
    
    func testAccountErrorTypes() {
        let errors: [AccountError] = [
            .noDataReceived,
            .httpError(error: "test"),
            .invalidJson(error: "test"),
            .invalidJsonType(json: "test"),
            .missingResultParamenter(json: ["key": "value"]),
            .invalidResultParamenter(json: ["key": "value"]),
            .tokenError(.noToken)
        ]
        
        // Test that all error types are properly instantiated
        XCTAssertEqual(errors.count, 7)
        for error in errors {
            // Just verify we can access the error - testing that it conforms to Error protocol
            _ = error as Error
        }
    }
    
    func testPositionErrorTypes() {
        let errors: [PositionError] = [
            .noDataReceived,
            .httpError(error: "test"),
            .invalidJson(error: "test"),
            .invalidJsonType(json: "test"),
            .missingResultParamenter(json: ["key": "value"]),
            .invalidResultParamenter(json: ["key": "value"]),
            .assetError(.missingResultParamenter(json: ["key": "value"])),
            .tokenError(.noToken)
        ]
        
        // Test that all error types are properly instantiated
        XCTAssertEqual(errors.count, 8)
        for error in errors {
            // Just verify we can access the error - testing that it conforms to Error protocol
            _ = error as Error
        }
    }

}