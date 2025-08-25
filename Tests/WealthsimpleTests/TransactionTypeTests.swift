//
//  TransactionTypeTests.swift
//
//
//  Created by Copilot on 2025-08-25.
//

import Foundation
@testable import Wealthsimple
import XCTest

final class TransactionTypeTests: XCTestCase {

    func testTransactionTypeCamelCaseConversion() {
        // Test that transaction types can be created from snake_case API values
        // that are converted to camelCase (as done in WealthsimpleTransaction init)
        
        let testCases: [(String, TransactionType)] = [
            ("custodian_fee", .custodianFee),
            ("home_buyers_plan", .homeBuyersPlan),
            ("charged_interest", .chargedInterest),
            ("non_resident_withholding_tax", .nonResidentWithholdingTax),
            ("risk_exposure_fee", .riskExposureFee),
            ("stock_distribution", .stockDistribution),
            ("stock_dividend", .stockDividend),
            ("transfer_in", .transferIn),
            ("transfer_out", .transferOut),
            ("withholding_tax", .withholdingTax),
            ("referral_bonus", .referralBonus),
            ("giveaway_bonus", .giveawayBonus),
            ("cashback_bonus", .cashbackBonus),
            ("online_bill_payment", .onlineBillPayment),
            ("manufactured_dividend", .manufacturedDividend),
            ("return_of_capital", .returnOfCapital),
            ("non_cash_distribution", .nonCashDistribution)
        ]
        
        for (snakeCaseString, expectedType) in testCases {
            let camelCaseString = snakeCaseString.camelCase
            let actualType = TransactionType(rawValue: camelCaseString)
            
            XCTAssertEqual(actualType, expectedType, 
                          "Failed conversion: '\(snakeCaseString)' -> '\(camelCaseString)' should map to \(expectedType)")
        }
    }
    
    func testTransactionTypeDirectRawValues() {
        // Test transaction types that have direct raw values (not converted from snake_case)
        let directCases: [(String, TransactionType)] = [
            ("buy", .buy),
            ("sell", .sell),
            ("dividend", .dividend),
            ("deposit", .deposit),
            ("withdrawal", .withdrawal),
            ("fee", .fee),
            ("forex", .forex),
            ("grant", .grant),
            ("hst", .hst),
            ("journal", .journal),
            ("redemption", .redemption),
            ("refund", .refund),
            ("reimbursement", .reimbursement),
            ("contribution", .contribution),
            ("interest", .interest)
        ]
        
        for (rawValue, expectedType) in directCases {
            let actualType = TransactionType(rawValue: rawValue)
            XCTAssertEqual(actualType, expectedType,
                          "Direct raw value '\(rawValue)' should map to \(expectedType)")
        }
    }
    
    func testTransactionTypeCustomRawValues() {
        // Test transaction types with completely custom raw values
        let customCases: [(String, TransactionType)] = [
            ("wealthsimplePaymentsTransferIn", .paymentTransferIn),
            ("wealthsimplePaymentsTransferOut", .paymentTransferOut),
            ("wealthsimplePaymentsSpend", .paymentSpend),
            ("fPLLoanedSecurities", .stockLoanBorrow),
            ("fPLRecalledSecurities", .stockLoanReturn)
        ]
        
        for (rawValue, expectedType) in customCases {
            let actualType = TransactionType(rawValue: rawValue)
            XCTAssertEqual(actualType, expectedType,
                          "Custom raw value '\(rawValue)' should map to \(expectedType)")
        }
    }
    
    func testTransactionTypeInvalidCamelCaseConversions() {
        // Test snake_case values that don't have corresponding transaction types
        let invalidSnakeCases = [
            "invalid_transaction_type",
            "unknown_type",
            "fake_transaction",
            "test_case"
        ]
        
        for invalidCase in invalidSnakeCases {
            let camelCase = invalidCase.camelCase
            let type = TransactionType(rawValue: camelCase)
            XCTAssertNil(type, "Invalid snake_case '\(invalidCase)' -> '\(camelCase)' should not map to any transaction type")
        }
    }
    
    func testTransactionTypeRoundTripConversion() {
        // Test that all transaction types can round-trip through their raw values
        let allTypes: [TransactionType] = [
            .buy, .contribution, .dividend, .custodianFee, .deposit, .fee, .forex,
            .grant, .homeBuyersPlan, .hst, .chargedInterest, .journal,
            .nonResidentWithholdingTax, .redemption, .riskExposureFee, .refund,
            .reimbursement, .sell, .stockDistribution, .stockDividend, .transferIn,
            .transferOut, .withholdingTax, .withdrawal, .paymentTransferIn,
            .paymentTransferOut, .referralBonus, .interest, .paymentSpend,
            .giveawayBonus, .cashbackBonus, .onlineBillPayment, .stockLoanBorrow,
            .stockLoanReturn, .manufacturedDividend, .returnOfCapital, .nonCashDistribution
        ]
        
        for originalType in allTypes {
            let rawValue = originalType.rawValue
            let reconstructedType = TransactionType(rawValue: rawValue)
            
            XCTAssertEqual(reconstructedType, originalType,
                          "Round-trip failed for \(originalType): rawValue '\(rawValue)' should reconstruct to original type")
        }
    }
    
    func testTransactionTypeCaseSensitivity() {
        // Test that transaction type matching is case-sensitive
        let caseSensitiveTests: [(String, TransactionType?)] = [
            ("Buy", nil),       // Should fail - capital B
            ("BUY", nil),       // Should fail - all caps
            ("Dividend", nil),  // Should fail - capital D
            ("DIVIDEND", nil)   // Should fail - all caps
        ]
        
        for (wrongCase, expectedType) in caseSensitiveTests {
            let type = TransactionType(rawValue: wrongCase)
            XCTAssertEqual(type, expectedType, "Case-sensitive test failed: '\(wrongCase)' should be nil")
        }
    }

}