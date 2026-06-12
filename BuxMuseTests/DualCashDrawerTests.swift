//
//  DualCashDrawerTests.swift
//  BuxMuseTests
//

import XCTest
import Combine
@testable import BuxMuse

@MainActor
final class DualCashDrawerTests: XCTestCase {
    var settings: SettingsStore!
    var settingsManager: AppSettingsManager!
    var brain: BuxMuseBrain!
    var localEngine: LocalFinancialIntelligenceEngine18!
    var viewModel: AddExpenseViewModel!

    override func setUp() {
        super.setUp()
        settings = SettingsStore.shared
        settings.resetAllData()
        
        // Setup initial physical cash balances
        settings.dualCashDrawerEnabled = true
        settings.primaryLocalCurrency = "USD"
        settings.secondaryTradingCurrency = "DOP"
        settings.cashLocalBalanceValue = 100.0
        settings.cashSecondaryBalanceValue = 5000.0
        
        let persistence = PersistenceController(inMemory: true)
        localEngine = LocalFinancialIntelligenceEngine18()
        let bridge = FinancialEngineBridge(engine: localEngine)
        let goals = GoalsEngine()
        let insights = InsightsEngine()
        
        brain = BuxMuseBrain(
            persistence: persistence,
            financialBridge: bridge,
            goalsEngine: goals,
            insightsEngine: insights
        )
        
        try? persistence.seedExpenseCatalogIfNeeded()
        
        settingsManager = AppSettingsManager()
        viewModel = AddExpenseViewModel(
            brain: brain,
            settingsManager: settingsManager,
            editing: nil,
            presetCategory: nil
        )
    }

    override func tearDown() {
        print("--- [TEST] Entering tearDown")
        print("--- [TEST] Resetting settings store data")
        settings.resetAllData()
        print("--- [TEST] settings = nil")
        settings = nil
        print("--- [TEST] brain = nil")
        brain = nil
        print("--- [TEST] localEngine = nil")
        localEngine = nil
        print("--- [TEST] viewModel = nil")
        viewModel = nil
        print("--- [TEST] settingsManager = nil")
        settingsManager = nil
        print("--- [TEST] Calling super.tearDown()")
        super.tearDown()
        print("--- [TEST] Finished super.tearDown()")
    }

    func testCashDrawerToggling() {
        // Assert initialized settings
        XCTAssertTrue(settings.dualCashDrawerEnabled)
        XCTAssertEqual(settings.cashLocalBalanceValue, 100.0)
        XCTAssertEqual(settings.cashSecondaryBalanceValue, 5000.0)
        
        // Turn off
        settings.dualCashDrawerEnabled = false
        XCTAssertFalse(settings.dualCashDrawerEnabled)
    }

    func testAddCashIncomeAdjustsBalance() {
        // Setup viewModel to log primary cash income
        viewModel.amountString = "50.00"
        viewModel.merchantName = "Project Bonus Cash"
        viewModel.selectedCategory = .income
        viewModel.paymentMethod = "Cash (USD)"
        
        let success = viewModel.saveTransaction()
        XCTAssertTrue(success)
        
        // Since we logged +$50.00 cash income, primary balance should go from $100.00 to $150.00
        XCTAssertEqual(settings.cashLocalBalanceValue, 150.0)
    }

    func testSpendCashExpenseAdjustsBalance() {
        // Setup viewModel to log secondary cash expense
        viewModel.amountString = "1000.00"
        viewModel.merchantName = "Taxi ride"
        viewModel.selectedCategory = .transport
        viewModel.paymentMethod = "Cash (DOP)"
        
        let success = viewModel.saveTransaction()
        XCTAssertTrue(success)
        
        // Spent 1000 DOP from 5000 DOP cash ledger in hand
        XCTAssertEqual(settings.cashSecondaryBalanceValue, 4000.0)
    }

    func testEditTransactionMethodFromCardToCash() {
        print("--- [TEST] Starting testEditTransactionMethodFromCardToCash")
        // Log a transaction with Card / Bank method (paymentMethod = nil)
        let tx = Transaction(
            id: UUID(),
            date: Date(),
            amount: MoneyAmount(value: -20.00, currencyCode: "USD"),
            merchantName: "Adobe Subscription",
            category: .subscriptions,
            paymentMethod: nil
        )
        
        print("--- [TEST] Saving transaction to brain")
        // Save it inside persistence first so edit VM can load it safely
        _ = try? brain.saveExpense(tx)
        
        print("--- [TEST] Initializing AddExpenseViewModel")
        // Create editor viewModel
        let editVM = AddExpenseViewModel(
            brain: brain,
            settingsManager: settingsManager,
            editing: tx,
            presetCategory: nil
        )
        
        print("--- [TEST] Checking paymentMethod is nil")
        XCTAssertNil(editVM.paymentMethod)
        
        print("--- [TEST] Shifting paymentMethod to Cash")
        // Shift payment method to Cash (USD)
        editVM.paymentMethod = "Cash (USD)"
        let success = editVM.saveTransaction()
        XCTAssertTrue(success)
        
        print("--- [TEST] Asserting cashLocalBalanceValue")
        // Should subtract 20.00 USD from $100.00 cash ledger
        XCTAssertEqual(settings.cashLocalBalanceValue, 80.0)
    }

    func testDeleteCashTransactionReversesBalance() {
        // Log a cash transaction
        let tx = Transaction(
            id: UUID(),
            date: Date(),
            amount: MoneyAmount(value: -15.00, currencyCode: "USD"),
            merchantName: "Street food",
            category: .groceries,
            paymentMethod: "Cash (USD)"
        )
        
        // Save it inside persistence using the safe public bridge
        _ = try? brain.saveExpense(tx)
        
        let editVM = AddExpenseViewModel(
            brain: brain,
            settingsManager: settingsManager,
            editing: tx,
            presetCategory: nil
        )
        
        XCTAssertEqual(editVM.paymentMethod, "Cash (USD)")
        
        // Perform delete
        XCTAssertNoThrow(try editVM.deleteExpense())
        
        // Deleting the -$15.00 cash expense reverses it, adding $15.00 back to the wallet
        XCTAssertEqual(settings.cashLocalBalanceValue, 115.0)
    }
}
