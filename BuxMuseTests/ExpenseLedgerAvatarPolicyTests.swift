//
//  ExpenseLedgerAvatarPolicyTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class ExpenseLedgerAvatarPolicyTests: XCTestCase {

    func testIncomeWithoutMerchantLinkUsesCategoryAvatar() {
        let record = makeRecord(name: "Salary", amount: 500, category: .income)
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
        XCTAssertNil(
            ExpenseLedgerAvatarPolicy.merchantLogoName(for: record, linkedMerchantName: "Salary")
        )
    }

    func testIncomeWithExplicitMerchantLinkUsesLogo() {
        let record = makeRecord(name: "Amazon refund", amount: 40, category: .income, merchantId: UUID())
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
        XCTAssertEqual(
            ExpenseLedgerAvatarPolicy.merchantLogoName(for: record, linkedMerchantName: "Amazon"),
            "Amazon"
        )
    }

    func testRefundWithoutMerchantUsesRefundSymbol() {
        let record = makeRecord(name: "Store refund", amount: 25, category: .shopping)
        XCTAssertTrue(record.isRefund)
        let style = ExpenseLedgerAvatarPolicy.resolvedStyle(for: record, categoryRecords: [])
        XCTAssertEqual(style.symbol, "arrow.uturn.backward.circle.fill")
    }

    func testSalaryQuickPickSymbol() {
        let record = makeRecord(name: "Salary", amount: 1200, category: .income)
        let style = ExpenseLedgerAvatarPolicy.resolvedStyle(for: record, categoryRecords: [])
        XCTAssertEqual(style.symbol, "briefcase.fill")
    }

    func testCustomIncomeLabelUsesDefaultIncomeSymbol() {
        let record = makeRecord(name: "Client payment", amount: 800, category: .income)
        let style = ExpenseLedgerAvatarPolicy.resolvedStyle(for: record, categoryRecords: [])
        XCTAssertEqual(style.symbol, "arrow.down.circle.fill")
    }

    private func makeRecord(
        name: String,
        amount: Decimal,
        category: TransactionCategory,
        merchantId: UUID? = nil
    ) -> ExpenseRecord {
        ExpenseRecord(
            name: name,
            amountValue: amount,
            currencyCode: "GBP",
            merchantId: merchantId,
            date: Date(),
            categoryRaw: category.rawValue,
            merchantName: name
        )
    }
}
