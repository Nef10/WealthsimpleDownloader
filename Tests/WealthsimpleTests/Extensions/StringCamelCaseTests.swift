//
//  StringCamelCaseTests.swift
//
//
//  Created by Steffen Kötte on 2021-09-15.
//

import Foundation
@testable import Wealthsimple
import XCTest

final class StringCamelCaseTests: XCTestCase {

    func testCamelCase() {
        XCTAssertEqual("".camelCase, "")

        XCTAssertEqual("ABC".camelCase, "aBC")
        XCTAssertEqual("abc".camelCase, "abc")
        XCTAssertEqual("aBc".camelCase, "aBc")

        XCTAssertEqual("abc def".camelCase, "abcDef")
        XCTAssertEqual("ABC DEF".camelCase, "aBCDEF")
        XCTAssertEqual("aBc dEf".camelCase, "aBcDEf")

        XCTAssertEqual("abc def ghi jkl".camelCase, "abcDefGhiJkl")
        XCTAssertEqual("a b c d e".camelCase, "aBCDE")

        XCTAssertEqual("a1a b c3c d e4e".camelCase, "a1aBC3cDE4e")

        XCTAssertEqual("abc-def&ghi+jkl%mno_pqr".camelCase, "abcDefGhiJklMnoPqr")
    }
    
    func testCamelCaseEdgeCases() {
        // Test single character
        XCTAssertEqual("a".camelCase, "a")
        XCTAssertEqual("A".camelCase, "a")
        
        // Test only separators
        XCTAssertEqual(" ".camelCase, "")
        XCTAssertEqual("   ".camelCase, "")
        XCTAssertEqual("-_&+%".camelCase, "")
        
        // Test separators at beginning and end - leading separators create empty first part
        // When removeFirst() is called, the actual first word becomes capitalized
        XCTAssertEqual(" abc".camelCase, "Abc")  // Empty string + "abc" -> "abc" becomes first, gets capitalized
        XCTAssertEqual("abc ".camelCase, "abc")  // "abc" + empty string -> "abc" stays lowercase
        XCTAssertEqual(" abc ".camelCase, "Abc") // Empty + "abc" + empty -> "abc" becomes first, gets capitalized
        XCTAssertEqual("-abc-".camelCase, "Abc") // Empty + "abc" + empty -> "abc" becomes first, gets capitalized
        
        // Test multiple consecutive separators
        XCTAssertEqual("abc   def".camelCase, "abcDef")
        XCTAssertEqual("abc---def".camelCase, "abcDef")
        XCTAssertEqual("abc-_&+%def".camelCase, "abcDef")
        
        // Test mixed separators
        XCTAssertEqual("abc def-ghi_jkl&mno+pqr%stu".camelCase, "abcDefGhiJklMnoPqrStu")
    }
    
    func testCamelCaseWithNumbers() {
        XCTAssertEqual("123".camelCase, "123")
        XCTAssertEqual("abc123".camelCase, "abc123")
        XCTAssertEqual("123abc".camelCase, "123abc")
        XCTAssertEqual("abc 123".camelCase, "abc123")
        XCTAssertEqual("123 abc".camelCase, "123Abc")
        XCTAssertEqual("a1 b2 c3".camelCase, "a1B2C3")
    }
    
    func testCamelCaseWithSpecialCharacters() {
        // Test unicode characters
        XCTAssertEqual("café latte".camelCase, "caféLatte")
        XCTAssertEqual("naïve approach".camelCase, "naïveApproach")
        
        // Test that alphanumeric detection works correctly
        XCTAssertEqual("test@email.com".camelCase, "testEmailCom")
        XCTAssertEqual("hello.world".camelCase, "helloWorld")
        XCTAssertEqual("version-1.0.0".camelCase, "version100")
    }
    
    func testCamelCaseRealWorldExamples() {
        // Test real-world API field names that might be converted
        XCTAssertEqual("security_id".camelCase, "securityId")
        XCTAssertEqual("account_id".camelCase, "accountId")
        XCTAssertEqual("market_price".camelCase, "marketPrice")
        XCTAssertEqual("position_date".camelCase, "positionDate")
        XCTAssertEqual("effective_date".camelCase, "effectiveDate")
        XCTAssertEqual("process_date".camelCase, "processDate")
        XCTAssertEqual("created_at".camelCase, "createdAt")
        XCTAssertEqual("updated_at".camelCase, "updatedAt")
        
        // Test transaction types that use camelCase conversion
        XCTAssertEqual("custodian_fee".camelCase, "custodianFee")
        XCTAssertEqual("home_buyers_plan".camelCase, "homeBuyersPlan")
        XCTAssertEqual("charged_interest".camelCase, "chargedInterest")
        XCTAssertEqual("non_resident_withholding_tax".camelCase, "nonResidentWithholdingTax")
        XCTAssertEqual("risk_exposure_fee".camelCase, "riskExposureFee")
        XCTAssertEqual("stock_distribution".camelCase, "stockDistribution")
        XCTAssertEqual("stock_dividend".camelCase, "stockDividend")
        XCTAssertEqual("transfer_in".camelCase, "transferIn")
        XCTAssertEqual("transfer_out".camelCase, "transferOut")
        XCTAssertEqual("withholding_tax".camelCase, "withholdingTax")
        XCTAssertEqual("referral_bonus".camelCase, "referralBonus")
        XCTAssertEqual("giveaway_bonus".camelCase, "giveawayBonus")
        XCTAssertEqual("cashback_bonus".camelCase, "cashbackBonus")
        XCTAssertEqual("online_bill_payment".camelCase, "onlineBillPayment")
        XCTAssertEqual("manufactured_dividend".camelCase, "manufacturedDividend")
        XCTAssertEqual("return_of_capital".camelCase, "returnOfCapital")
        XCTAssertEqual("non_cash_distribution".camelCase, "nonCashDistribution")
    }

}
