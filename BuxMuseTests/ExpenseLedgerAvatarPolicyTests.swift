//
//  ExpenseLedgerAvatarPolicyTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class ExpenseLedgerAvatarPolicyTests: XCTestCase {

    func testExpenseMerchantNameShowsLogoWithoutLink() {
        let record = ExpenseRecord(
            name: "Groceries",
            amountValue: -42,
            currencyCode: "GBP",
            date: Date(),
            categoryRaw: TransactionCategory.shopping.rawValue,
            merchantName: "Tesco"
        )
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
        XCTAssertEqual(ExpenseLedgerAvatarPolicy.resolvedMerchantDisplayName(for: record), "Tesco")
    }

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

    func testInternetTransferUsesMoneyOutIcon() {
        let record = makeRecord(name: "Internet Transfer", amount: -120, category: .utilities)
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
        let style = ExpenseLedgerAvatarPolicy.resolvedStyle(for: record, categoryRecords: [])
        XCTAssertEqual(style.symbol, "arrow.up.circle.fill")
    }

    func testWifeTransferInUsesMoneyInIconNotMerchant() {
        let record = makeRecord(name: "Jane Smith", amount: 200, category: .income, merchantId: UUID())
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
        let style = ExpenseLedgerAvatarPolicy.resolvedStyle(for: record, categoryRecords: [])
        XCTAssertEqual(style.symbol, "banknote.fill")
    }

    func testTescoStillUsesMerchantLogo() {
        let record = ExpenseRecord(
            name: "Groceries",
            amountValue: -42,
            currencyCode: "GBP",
            date: Date(),
            categoryRaw: TransactionCategory.groceries.rawValue,
            merchantName: "Tesco"
        )
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
    }

    func testPayPalTickerWalletImportUsesMerchantLogoInList() {
        let record = ExpenseRecord(
            name: "PYPL",
            amountValue: -19.99,
            currencyCode: "GBP",
            date: Date(),
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "PYPL"),
            categoryRaw: TransactionCategory.personal.rawValue,
            merchantName: "PYPL"
        )
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
    }

    func testDominoPizzaWalletImportUsesMerchantLogoInList() {
        UserDefaults.standard.set("GB", forKey: "selected_country_id")
        defer { UserDefaults.standard.removeObject(forKey: "selected_country_id") }

        let record = ExpenseRecord(
            name: "Domino Pizza Milton",
            amountValue: -24.50,
            currencyCode: "GBP",
            date: Date(),
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "Domino Pizza Milton"),
            categoryRaw: TransactionCategory.restaurants.rawValue,
            merchantName: "Domino Pizza Milton"
        )
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
    }

    func testSalaryIncomeNeverUsesMerchantLogo() {
        let record = makeRecord(name: "Salary", amount: 500, category: .income, merchantId: UUID())
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
    }

    func testPersonalCreditNeverUsesMerchantLogo() {
        let record = makeRecord(name: "Jane Smith", amount: 200, category: .personal)
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
    }

    func testPresentationEngineHidesWifeTransferLogo() {
        let record = makeRecord(name: "Jane Smith", amount: 200, category: .income, merchantId: UUID())
        let presentation = MerchantLogoPresentationEngine.build(record: record, linkedMerchant: nil)
        XCTAssertFalse(presentation.showMerchantLogo)
    }

    func testWalletNotesOnlyLabelShowsMerchantLogo() {
        UserDefaults.standard.set("GB", forKey: "selected_country_id")
        defer { UserDefaults.standard.removeObject(forKey: "selected_country_id") }

        let record = ExpenseRecord(
            name: "Shopping",
            amountValue: -42,
            currencyCode: "GBP",
            date: Date(),
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "Tesco Express"),
            categoryRaw: TransactionCategory.shopping.rawValue,
            merchantName: ""
        )
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
        XCTAssertEqual(
            ExpenseLedgerAvatarPolicy.resolvedMerchantDisplayName(for: record),
            "Tesco Express"
        )
    }

    func testPersonNameCreditNeverUsesMerchantLogo() {
        let record = makeRecord(name: "Victoria Smith", amount: 200, category: .income, merchantId: UUID())
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
    }

    func testCashWithdrawalNeverUsesMerchantLogo() {
        let record = makeRecord(name: "ATM Withdrawal", amount: -100, category: .personal)
        XCTAssertTrue(ExpenseLedgerAvatarPolicy.isMoneyTransfer(for: record))
        XCTAssertFalse(ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record))
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
