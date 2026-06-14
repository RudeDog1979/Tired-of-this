//
//  ConsumerFeaturesTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class ConsumerFeaturesTests: XCTestCase {

    func testSplitExpenseAttributesEachLineToCategory() {
        let groceriesId = UUID()
        let householdId = UUID()
        let record = ExpenseRecord(
            id: UUID(),
            name: "Tesco",
            amountValue: -85,
            currencyCode: "GBP",
            categoryId: groceriesId,
            date: Date(),
            categoryRaw: TransactionCategory.groceries.rawValue,
            merchantName: "Tesco",
            isCategorySplit: true,
            splitLines: [
                ExpenseSplitLineRecord(id: UUID(), categoryId: groceriesId, categoryRaw: TransactionCategory.groceries.rawValue, amountValue: -60, sortOrder: 0),
                ExpenseSplitLineRecord(id: UUID(), categoryId: householdId, categoryRaw: TransactionCategory.other.rawValue, amountValue: -25, sortOrder: 1)
            ]
        )

        let lines = ExpenseBudgetAttribution.lines(for: record)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].amount, 60)
        XCTAssertEqual(lines[1].amount, 25)
        XCTAssertEqual(lines[0].categoryRaw, TransactionCategory.groceries.rawValue)
    }

    func testEnvelopeSpentUsesSplitLines() {
        let groceriesId = UUID()
        let envelope = CustomBudgetCategory(
            name: "Groceries",
            targetAmount: 200,
            categoryId: groceriesId,
            systemCategoryRaw: TransactionCategory.groceries.rawValue
        )
        let record = ExpenseRecord(
            id: UUID(),
            name: "Shop",
            amountValue: -100,
            currencyCode: "GBP",
            categoryId: groceriesId,
            date: Date(),
            categoryRaw: TransactionCategory.groceries.rawValue,
            merchantName: "Shop",
            isCategorySplit: true,
            splitLines: [
                ExpenseSplitLineRecord(id: UUID(), categoryId: groceriesId, categoryRaw: TransactionCategory.groceries.rawValue, amountValue: -40, sortOrder: 0),
                ExpenseSplitLineRecord(id: UUID(), categoryId: UUID(), categoryRaw: TransactionCategory.restaurants.rawValue, amountValue: -60, sortOrder: 1)
            ]
        )

        let spent = BudgetEnvelopeEngine.spent(
            for: envelope,
            records: [record],
            categoryRecords: [],
            period: DateInterval(start: .distantPast, end: .distantFuture)
        )
        XCTAssertEqual(spent, 40)
    }

    func testDebtEstimatedPayoffMonthWithAPR() {
        var debt = Debt(
            name: "Card",
            type: .creditCard,
            currentBalance: 1200,
            aprPercent: 24,
            minimumPayment: 100
        )
        XCTAssertNotNil(debt.estimatedPayoffMonth)
    }

    @MainActor
    func testArchiveRoundTripIncludesDebts() throws {
        let settings = SettingsStore.shared
        let debt = Debt(name: "Visa", type: .creditCard, currentBalance: 500)
        let payload = try BuxMuseArchiveService.buildPayload(
            settings: settings,
            hustles: [],
            selectedHustleId: nil,
            transactions: [],
            goals: [],
            debts: [debt],
            studioSnapshot: nil,
            simpleSnapshot: nil
        )
        let encrypted = try BuxMuseArchiveService.encrypt(payload, password: "debts-test", includeRecoveryKey: false)
        let decrypted = try BuxMuseArchiveService.decrypt(encrypted.archiveData, password: "debts-test")
        XCTAssertEqual(decrypted.manifest.debtCount, 1)
        XCTAssertEqual(decrypted.debts.first?.name, "Visa")
    }
}
