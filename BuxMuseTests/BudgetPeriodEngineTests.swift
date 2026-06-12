//
//  BudgetPeriodEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class BudgetPeriodEngineTests: XCTestCase {

    private let period = DateInterval(start: Date(timeIntervalSince1970: 0), duration: 86_400 * 7)

    func testResolveEffectiveLimitUsesEarnedWhenNoCap() {
        XCTAssertEqual(BudgetPeriodEngine.resolveEffectiveLimit(earned: 500, cap: nil), 500)
        XCTAssertEqual(BudgetPeriodEngine.resolveEffectiveLimit(earned: 500, cap: 0), 500)
    }

    func testResolveEffectiveLimitUsesMinimumWhenCapSet() {
        XCTAssertEqual(BudgetPeriodEngine.resolveEffectiveLimit(earned: 3800, cap: 800), 800)
        XCTAssertEqual(BudgetPeriodEngine.resolveEffectiveLimit(earned: 300, cap: 800), 300)
    }

    func testResolveEffectiveLimitUsesCapWhenNoIncomeYet() {
        XCTAssertEqual(BudgetPeriodEngine.resolveEffectiveLimit(earned: 0, cap: 800), 800)
        XCTAssertEqual(BudgetPeriodEngine.resolveEffectiveLimit(earned: 0, cap: nil), 0)
    }

    func testIncomeAccumulatesWithinPeriod() {
        let records = [
            makeIncome(amount: 300, date: period.start.addingTimeInterval(3600)),
            makeIncome(amount: 200, date: period.start.addingTimeInterval(86_400))
        ]
        let result = BudgetPeriodEngine.computeStandardBudget(
            records: records,
            fundingSource: .salary,
            period: period,
            spendingCap: 0,
            categoryRecords: []
        )
        XCTAssertEqual(result.earnedThisPeriod, 500)
        XCTAssertEqual(result.effectiveLimit, 500)
        XCTAssertEqual(result.remaining, 500)
    }

    func testEssentialsExcludedFromDiscretionarySpent() {
        let records = [
            makeIncome(amount: 1000, date: period.start.addingTimeInterval(100)),
            makeExpense(amount: 400, category: .housing, date: period.start.addingTimeInterval(200)),
            makeExpense(amount: 100, category: .groceries, date: period.start.addingTimeInterval(300)),
            makeExpense(amount: 50, category: .utilities, date: period.start.addingTimeInterval(400))
        ]
        let result = BudgetPeriodEngine.computeStandardBudget(
            records: records,
            fundingSource: .salary,
            period: period,
            spendingCap: 0,
            categoryRecords: []
        )
        XCTAssertEqual(result.essentialSpent, 450)
        XCTAssertEqual(result.discretionarySpent, 100)
        XCTAssertEqual(result.remaining, 900)
    }

    func testNegativeRemainingWhenSpentWithoutIncome() {
        let records = [
            makeExpense(amount: 75, category: .groceries, date: period.start.addingTimeInterval(100))
        ]
        let result = BudgetPeriodEngine.computeStandardBudget(
            records: records,
            fundingSource: .salary,
            period: period,
            spendingCap: 0,
            categoryRecords: []
        )
        XCTAssertEqual(result.effectiveLimit, 0)
        XCTAssertEqual(result.remaining, -75)
    }

    func testSpendingCapLimitsEffectiveBudget() {
        let records = [
            makeIncome(amount: 3800, date: period.start.addingTimeInterval(100)),
            makeExpense(amount: 600, category: .groceries, date: period.start.addingTimeInterval(200))
        ]
        let result = BudgetPeriodEngine.computeStandardBudget(
            records: records,
            fundingSource: .salary,
            period: period,
            spendingCap: 800,
            categoryRecords: []
        )
        XCTAssertEqual(result.earnedThisPeriod, 3800)
        XCTAssertEqual(result.effectiveLimit, 800)
        XCTAssertEqual(result.remaining, 200)
    }

    func testBudgetingModeMigratesIncomeBasedOnDecode() throws {
        let json = "\"Income-based\""
        let data = Data(json.utf8)
        let mode = try JSONDecoder().decode(BudgetingMode.self, from: data)
        XCTAssertEqual(mode, .simple)
    }

    func testBudgetingModeStandardCatalogLabel() {
        let label = BudgetingMode.simple.catalogLabel(locale: Locale(identifier: "en"))
        XCTAssertEqual(label, "Standard")
    }

    func testIncomeFundingSourceCatalogLabels() {
        XCTAssertEqual(
            IncomeFundingSource.salary.catalogLabel(locale: Locale(identifier: "en")),
            "Paycheck & salary"
        )
        XCTAssertEqual(
            IncomeFundingSource.other.catalogLabel(locale: Locale(identifier: "en")),
            "Freelance & other"
        )
    }

    func testIsEssentialLivingExpense() {
        let housing = makeExpense(amount: 10, category: .housing, date: Date())
        let utilities = makeExpense(amount: 10, category: .utilities, date: Date())
        let food = makeExpense(amount: 10, category: .groceries, date: Date())
        XCTAssertTrue(BudgetPeriodEngine.isEssentialLivingExpense(housing, categoryRecords: []))
        XCTAssertTrue(BudgetPeriodEngine.isEssentialLivingExpense(utilities, categoryRecords: []))
        XCTAssertFalse(BudgetPeriodEngine.isEssentialLivingExpense(food, categoryRecords: []))
    }

    func testStandardBudgetWarningOverLimit() {
        let records = [
            makeIncome(amount: 500, date: period.start.addingTimeInterval(100)),
            makeExpense(amount: 450, category: .groceries, date: period.start.addingTimeInterval(200))
        ]
        let warning = BudgetPeriodEngine.projectedStandardBudgetWarning(
            records: records,
            fundingSource: .salary,
            period: period,
            spendingCap: 0,
            categoryRecords: [],
            additionalAmount: 100,
            additionalIsEssential: false,
            approachingThresholdPercent: 80
        )
        XCTAssertEqual(warning?.status, .over)
    }

    func testStandardBudgetWarningSkipsEssentials() {
        let records = [makeIncome(amount: 500, date: period.start.addingTimeInterval(100))]
        let warning = BudgetPeriodEngine.projectedStandardBudgetWarning(
            records: records,
            fundingSource: .salary,
            period: period,
            spendingCap: 0,
            categoryRecords: [],
            additionalAmount: 400,
            additionalIsEssential: true,
            approachingThresholdPercent: 80
        )
        XCTAssertNil(warning)
    }

    func testStandardBudgetWarningWithoutIncomeLogged() {
        let warning = BudgetPeriodEngine.projectedStandardBudgetWarning(
            records: [],
            fundingSource: .salary,
            period: period,
            spendingCap: 0,
            categoryRecords: [],
            additionalAmount: 25,
            additionalIsEssential: false,
            approachingThresholdPercent: 80
        )
        XCTAssertEqual(warning?.status, .over)
    }

    func testStudioBridgeAddsSupplementalEarned() {
        let entry = SimpleStudioEntry(
            kind: .income,
            amount: 250,
            createdAt: period.start.addingTimeInterval(3600)
        )
        let supplement = StandardBudgetStudioBridge.supplementalIncome(
            period: period,
            entries: [entry],
            incomeRecords: [],
            fundingSource: .other,
            studioEnabled: true,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 250)
        XCTAssertEqual(supplement.excludedByDedup, 0)

        let result = BudgetPeriodEngine.computeStandardBudget(
            records: [],
            fundingSource: .other,
            period: period,
            spendingCap: 0,
            categoryRecords: [],
            supplementalEarned: supplement.counted
        )
        XCTAssertEqual(result.earnedThisPeriod, 250)
        XCTAssertEqual(result.effectiveLimit, 250)
    }

    func testStudioBridgeDisabledReturnsZero() {
        let entry = SimpleStudioEntry(kind: .income, amount: 100, createdAt: period.start)
        let supplement = StandardBudgetStudioBridge.supplementalIncome(
            period: period,
            entries: [entry],
            incomeRecords: [],
            fundingSource: .other,
            studioEnabled: true,
            includeInBudget: false
        )
        XCTAssertEqual(supplement.counted, 0)
    }

    func testStudioBridgeExcludesEntriesOutsidePayPeriod() {
        let inside = SimpleStudioEntry(kind: .income, amount: 100, createdAt: period.start.addingTimeInterval(100))
        let outside = SimpleStudioEntry(kind: .income, amount: 999, createdAt: period.end.addingTimeInterval(100))
        let supplement = StandardBudgetStudioBridge.supplementalIncome(
            period: period,
            entries: [inside, outside],
            incomeRecords: [],
            fundingSource: .other,
            studioEnabled: true,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 100)
    }

    func testStudioBridgeDedupSkipsMatchingAddIncome() {
        let entry = SimpleStudioEntry(kind: .income, amount: 250, createdAt: period.start.addingTimeInterval(3600))
        let income = makeIncome(amount: 250, date: period.start.addingTimeInterval(7200))
        let supplement = StandardBudgetStudioBridge.supplementalIncome(
            period: period,
            entries: [entry],
            incomeRecords: [income],
            fundingSource: .salary,
            studioEnabled: true,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 0)
        XCTAssertEqual(supplement.excludedByDedup, 250)
    }

    func testStudioBridgeDedupAllowsSameAmountOnDifferentDays() {
        let entry = SimpleStudioEntry(kind: .income, amount: 250, createdAt: period.start.addingTimeInterval(86_400))
        let income = makeIncome(amount: 250, date: period.start.addingTimeInterval(3600))
        let supplement = StandardBudgetStudioBridge.supplementalIncome(
            period: period,
            entries: [entry],
            incomeRecords: [income],
            fundingSource: .other,
            studioEnabled: true,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 250)
        XCTAssertEqual(supplement.excludedByDedup, 0)
    }

    func testProStudioBridgeAddsPaidInvoicesInPeriod() {
        let clientId = UUID()
        let invoice = StudioInvoice(
            clientId: clientId,
            status: .paid,
            total: 420,
            paymentDate: period.start.addingTimeInterval(3600)
        )
        let supplement = StandardBudgetStudioBridge.proSupplementalIncome(
            period: period,
            invoices: [invoice],
            incomeRecords: [],
            fundingSource: .other,
            studioEnabled: true,
            studioMode: .pro,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 420)

        let result = BudgetPeriodEngine.computeStandardBudget(
            records: [],
            fundingSource: .other,
            period: period,
            spendingCap: 0,
            categoryRecords: [],
            supplementalEarned: supplement.counted
        )
        XCTAssertEqual(result.earnedThisPeriod, 420)
    }

    func testProStudioBridgeIgnoresUnpaidInvoices() {
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .sent,
            total: 500,
            paymentDate: period.start.addingTimeInterval(3600)
        )
        let supplement = StandardBudgetStudioBridge.proSupplementalIncome(
            period: period,
            invoices: [invoice],
            incomeRecords: [],
            fundingSource: .other,
            studioEnabled: true,
            studioMode: .pro,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 0)
    }

    func testProStudioBridgeExcludesInvoicesOutsidePayPeriod() {
        let inside = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            total: 100,
            paymentDate: period.start.addingTimeInterval(100)
        )
        let outside = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            total: 999,
            paymentDate: period.end.addingTimeInterval(100)
        )
        let supplement = StandardBudgetStudioBridge.proSupplementalIncome(
            period: period,
            invoices: [inside, outside],
            incomeRecords: [],
            fundingSource: .other,
            studioEnabled: true,
            studioMode: .pro,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 100)
    }

    func testProStudioBridgeDisabledWhenSimpleMode() {
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            total: 300,
            paymentDate: period.start
        )
        let supplement = StandardBudgetStudioBridge.proSupplementalIncome(
            period: period,
            invoices: [invoice],
            incomeRecords: [],
            fundingSource: .other,
            studioEnabled: true,
            studioMode: .simple,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 0)
    }

    func testProStudioBridgeDedupSkipsMatchingAddIncome() {
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            total: 420,
            paymentDate: period.start.addingTimeInterval(3600)
        )
        let income = makeIncome(amount: 420, date: period.start.addingTimeInterval(7200))
        let supplement = StandardBudgetStudioBridge.proSupplementalIncome(
            period: period,
            invoices: [invoice],
            incomeRecords: [income],
            fundingSource: .salary,
            studioEnabled: true,
            studioMode: .pro,
            includeInBudget: true
        )
        XCTAssertEqual(supplement.counted, 0)
        XCTAssertEqual(supplement.excludedByDedup, 420)
    }

    // MARK: - Helpers

    private func makeIncome(amount: Decimal, date: Date) -> ExpenseRecord {
        makeRecord(name: "Paycheck", amount: amount, category: .income, date: date)
    }

    private func makeExpense(amount: Decimal, category: TransactionCategory, date: Date) -> ExpenseRecord {
        makeRecord(name: "Expense", amount: -amount, category: category, date: date)
    }

    private func makeRecord(name: String, amount: Decimal, category: TransactionCategory, date: Date) -> ExpenseRecord {
        ExpenseRecord(
            id: UUID(),
            name: name,
            amountValue: amount,
            currencyCode: "GBP",
            date: date,
            categoryRaw: category.rawValue,
            merchantName: name
        )
    }
}
