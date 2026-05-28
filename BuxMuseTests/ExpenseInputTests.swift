//
//  ExpenseInputTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

@MainActor
final class ExpenseInputTests: XCTestCase {
    var engine: LocalFinancialIntelligenceEngine18!
    var settingsManager: AppSettingsManager!
    var brain: BuxMuseBrain!
    var viewModel: AddExpenseViewModel!

    override func setUp() {
        super.setUp()
        engine = LocalFinancialIntelligenceEngine18()
        settingsManager = AppSettingsManager()
        let persistence = PersistenceController(inMemory: true)
        let bridge = FinancialEngineBridge(engine: engine)
        brain = BuxMuseBrain(
            persistence: persistence,
            financialBridge: bridge,
            goalsEngine: GoalsEngine(),
            insightsEngine: InsightsEngine()
        )
        try? persistence.seedExpenseCatalogIfNeeded()
        viewModel = AddExpenseViewModel(brain: brain, settingsManager: settingsManager)
    }

    override func tearDown() {
        viewModel = nil
        brain = nil
        settingsManager = nil
        engine = nil
        super.tearDown()
    }

    func testAutocompleteSuggestions() {
        let tx = Transaction(
            date: Date(),
            amount: MoneyAmount(value: -25.50, currencyCode: "USD"),
            merchantName: "Starbucks Coffee",
            category: .restaurants
        )
        try? brain.saveExpense(tx)

        let txs = engine.allTransactions()
        XCTAssertEqual(txs.count, 1)

        let autocomplete = MerchantAutocompleteEngine(engine: engine)
        let suggestions = autocomplete.suggestions(for: "Star")
        XCTAssertTrue(suggestions.contains("Starbucks Coffee"))
    }

    func testPredictiveDefaultsFromBrain() throws {
        let tx = Transaction(
            date: Date(),
            amount: MoneyAmount(value: -15.99, currencyCode: "USD"),
            merchantName: "Netflix",
            category: .subscriptions
        )
        try brain.saveExpense(tx)

        viewModel.merchantName = ""
        viewModel.amountString = ""
        viewModel.selectedCategory = .other
        viewModel.merchantName = "Netflix"

        XCTAssertEqual(viewModel.selectedCategory, .subscriptions)
        XCTAssertEqual(viewModel.amountString, "15.99")
    }

    func testMerchantNameNormalizationOnSave() {
        viewModel.merchantName = "Whole Foods Market Ltd 🍏"
        viewModel.amountString = "42.00"
        viewModel.selectedCategory = .groceries

        let saved = viewModel.saveTransaction()
        XCTAssertTrue(saved)

        let transactions = engine.allTransactions()
        XCTAssertEqual(transactions.count, 1)

        let savedTx = transactions.first!
        XCTAssertEqual(savedTx.merchantName, "Whole Foods Market")
        XCTAssertEqual(savedTx.amount.value, -42.00)
    }

    func testIncomeSavedAsPositiveExpenseAsNegative() throws {
        viewModel.merchantName = "Target"
        viewModel.amountString = "10.00"
        viewModel.selectedCategory = .groceries
        XCTAssertTrue(viewModel.saveTransaction())

        viewModel.merchantName = "Acme Corp"
        viewModel.amountString = "1000.00"
        viewModel.selectedCategory = .income
        XCTAssertTrue(viewModel.saveTransaction())

        let txs = engine.allTransactions()
        XCTAssertEqual(txs.count, 2)

        let targetTx = txs.first(where: { $0.merchantName == "Target" })
        XCTAssertEqual(targetTx?.amount.value, -10.00)

        let acmeTx = txs.first(where: { $0.merchantName.localizedCaseInsensitiveContains("acme") })
        XCTAssertEqual(acmeTx?.amount.value, 1000.00)
    }

    func testExpensePersistsInSwiftData() throws {
        viewModel.merchantName = "Persist Cafe"
        viewModel.amountString = "5.00"
        viewModel.selectedCategory = .restaurants
        XCTAssertTrue(viewModel.saveTransaction())

        let fetched = try brain.persistence.fetchAllExpenses()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.merchantName, "Persist Cafe")
    }

    func testEmotionalTagPersistsInSwiftData() throws {
        viewModel.merchantName = "Treat Yourself"
        viewModel.amountString = "12.00"
        viewModel.selectedCategory = .restaurants
        viewModel.emotionTag = "joy"
        XCTAssertTrue(viewModel.saveTransaction())

        let records = try brain.fetchAllExpenseRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.emotion, "joy")

        let refetched = try XCTUnwrap(try brain.fetchExpenseRecord(id: records[0].id))
        XCTAssertEqual(refetched.emotion, "joy")
    }
}
