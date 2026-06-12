//
//  WorkspaceNexusTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

@MainActor
final class WorkspaceNexusTests: XCTestCase {
    var settings: SettingsStore!
    var hustleManager: HustleManager!
    var brain: BuxMuseBrain!
    var persistence: PersistenceController!

    override func setUp() {
        super.setUp()
        settings = SettingsStore.shared
        settings.resetAllData()

        UserDefaults.standard.removeObject(forKey: "buxmuse.sidehustles.list")
        UserDefaults.standard.removeObject(forKey: "buxmuse.sidehustles.selectedId")
        UserDefaults.standard.set(false, forKey: "buxmuse.sidehustle.enabled")

        hustleManager = HustleManager.shared
        hustleManager.replaceAll([], selectedId: nil)

        persistence = PersistenceController(inMemory: true)
        let engine = LocalFinancialIntelligenceEngine18()
        brain = BuxMuseBrain(
            persistence: persistence,
            financialBridge: FinancialEngineBridge(engine: engine),
            goalsEngine: GoalsEngine(),
            insightsEngine: InsightsEngine()
        )
        try? persistence.seedExpenseCatalogIfNeeded()
    }

    override func tearDown() {
        settings.sideHustleMatrixEnabled = false
        settings.resetAllData()
        hustleManager.replaceAll([], selectedId: nil)
        brain = nil
        persistence = nil
        hustleManager = nil
        settings = nil
        super.tearDown()
    }

    func testHustleDecodesLegacyJSONWithoutNexusFields() throws {
        let json = """
        {"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"LLC","colorHex":"#5A55F5","isActive":true}
        """
        let hustle = try JSONDecoder().decode(Hustle.self, from: Data(json.utf8))
        XCTAssertNil(hustle.themeName)
        XCTAssertNil(hustle.currencyCode)
        XCTAssertNil(hustle.cardRules)
        XCTAssertNil(hustle.merchantRules)
    }

    func testHustleEncodesRoundTripWithNexusFields() throws {
        let hustle = Hustle(
            name: "LLC",
            themeName: "midnightOcean",
            currencyCode: "EUR",
            cardRules: ["visa"],
            merchantRules: ["aws", "adobe"]
        )
        let data = try JSONEncoder().encode(hustle)
        let decoded = try JSONDecoder().decode(Hustle.self, from: data)
        XCTAssertEqual(decoded.themeName, "midnightOcean")
        XCTAssertEqual(decoded.currencyCode, "EUR")
        XCTAssertEqual(decoded.cardRules, ["visa"])
        XCTAssertEqual(decoded.merchantRules, ["aws", "adobe"])
    }

    func testRouteHustleIdMatchesMerchantKeyword() {
        let amazonHustle = Hustle(name: "Shop", merchantRules: ["amazon"])
        hustleManager.replaceAll([amazonHustle], selectedId: nil)

        let id = hustleManager.routeHustleId(
            merchantName: "Amazon Shopping",
            notes: nil,
            paymentMethod: nil
        )
        XCTAssertEqual(id, amazonHustle.id)
    }

    func testRouteHustleIdMatchesPaymentMethodKeyword() {
        let cardHustle = Hustle(name: "Cards", cardRules: ["visa"])
        hustleManager.replaceAll([cardHustle], selectedId: nil)

        let id = hustleManager.routeHustleId(
            merchantName: "Coffee Shop",
            notes: nil,
            paymentMethod: "Visa"
        )
        XCTAssertEqual(id, cardHustle.id)
    }

    func testRouteHustleIdSkipsInactiveHustle() {
        let inactive = Hustle(name: "Old", isActive: false, merchantRules: ["aws"])
        let active = Hustle(name: "New", merchantRules: ["shopify"])
        hustleManager.replaceAll([inactive, active], selectedId: nil)

        let id = hustleManager.routeHustleId(
            merchantName: "AWS Bill",
            notes: nil,
            paymentMethod: nil
        )
        XCTAssertNil(id)
    }

    func testRouteHustleIdReturnsNilWhenNoMatch() {
        hustleManager.replaceAll([Hustle(name: "LLC", merchantRules: ["adobe"])], selectedId: nil)
        XCTAssertNil(hustleManager.routeHustleId(merchantName: "Coffee", notes: nil, paymentMethod: nil))
    }

    func testRouteHustleIdFirstMatchWins() {
        let first = Hustle(name: "First", merchantRules: ["netflix"])
        let second = Hustle(name: "Second", merchantRules: ["netflix"])
        hustleManager.replaceAll([first, second], selectedId: nil)

        let id = hustleManager.routeHustleId(
            merchantName: "Netflix",
            notes: nil,
            paymentMethod: nil
        )
        XCTAssertEqual(id, first.id)
    }

    func testWorkspaceCurrencyContextUsesDesktopCurrency() {
        settings.sideHustleMatrixEnabled = true
        let hustle = Hustle(name: "EU", currencyCode: "EUR")
        hustleManager.replaceAll([hustle], selectedId: hustle.id)

        let global = AppSettingsManager.currencySetting(for: "USD")
        let resolved = WorkspaceCurrencyContext.activeDisplayCurrency(global: global)
        XCTAssertEqual(resolved.id, "EUR")
    }

    func testWorkspaceCurrencyContextFallsBackToGlobal() {
        settings.sideHustleMatrixEnabled = true
        hustleManager.replaceAll([Hustle(name: "Main")], selectedId: nil)

        let global = AppSettingsManager.currencySetting(for: "USD")
        let resolved = WorkspaceCurrencyContext.activeDisplayCurrency(global: global)
        XCTAssertEqual(resolved.id, "USD")
    }

    func testSaveExpenseRecordAutoRoutesOnCreateWhenUnassigned() throws {
        settings.sideHustleMatrixEnabled = true
        let amazonHustle = Hustle(name: "Shop", merchantRules: ["amazon"])
        hustleManager.replaceAll([amazonHustle], selectedId: nil)

        let record = ExpenseRecord(
            name: "Amazon Shopping",
            amountValue: -42,
            currencyCode: "USD",
            date: Date(),
            categoryRaw: TransactionCategory.shopping.rawValue,
            merchantName: "Amazon Shopping",
            hustleId: nil
        )

        let saved = try brain.saveExpenseRecord(record)
        XCTAssertEqual(saved.hustleId, amazonHustle.id)
    }

    func testEnsureDefaultWorkspaceCreatesPersonal() {
        hustleManager.replaceAll([], selectedId: nil)
        XCTAssertTrue(hustleManager.ensureDefaultWorkspaceIfNeeded())
        XCTAssertEqual(hustleManager.hustles.first?.name, "Personal")
    }

    func testActiveWorkspaceBudgetResolution() {
        settings.sideHustleMatrixEnabled = true
        let hustle = Hustle(name: "LLC", budgetLimit: 2500)
        hustleManager.replaceAll([hustle], selectedId: hustle.id)

        let budget = WorkspaceCurrencyContext.activeWorkspaceBudget()
        XCTAssertEqual(budget?.workspaceName, "LLC")
        XCTAssertEqual(budget?.limit, 2500)
    }

    func testSaveIncomeAutoRoutesOnCreate() throws {
        settings.sideHustleMatrixEnabled = true
        let hustle = Hustle(name: "Freelance", merchantRules: ["deposit"])
        hustleManager.replaceAll([hustle], selectedId: nil)

        let record = ExpenseRecord(
            name: "Client Deposit",
            amountValue: 500,
            currencyCode: "USD",
            date: Date(),
            categoryRaw: TransactionCategory.income.rawValue,
            merchantName: "Client Deposit",
            hustleId: nil
        )

        let saved = try brain.saveExpenseRecord(record)
        XCTAssertEqual(saved.hustleId, hustle.id)
    }

    func testBrainSaveExpenseRoutesCashDrawerPath() throws {
        settings.sideHustleMatrixEnabled = true
        let hustle = Hustle(name: "Biz", cardRules: ["cash"])
        hustleManager.replaceAll([hustle], selectedId: nil)

        let tx = Transaction(
            date: Date(),
            amount: MoneyAmount(value: -25, currencyCode: "USD"),
            merchantName: "Street vendor",
            category: .other,
            paymentMethod: "Cash (USD)"
        )

        _ = try brain.saveExpense(tx)
        let saved = try XCTUnwrap(brain.fetchAllExpenseRecords().first)
        XCTAssertEqual(saved.hustleId, hustle.id)
    }

    func testSaveExpenseRecordDoesNotReRouteOnEdit() throws {
        settings.sideHustleMatrixEnabled = true
        let amazonHustle = Hustle(name: "Shop", merchantRules: ["amazon"])
        hustleManager.replaceAll([amazonHustle], selectedId: nil)

        let record = ExpenseRecord(
            name: "Coffee",
            amountValue: -5,
            currencyCode: "USD",
            date: Date(),
            categoryRaw: TransactionCategory.restaurants.rawValue,
            merchantName: "Coffee",
            hustleId: nil
        )
        let created = try brain.saveExpenseRecord(record)
        XCTAssertNil(created.hustleId)

        var edited = created
        edited.merchantName = "Amazon Shopping"
        edited.notes = "Prime"
        let saved = try brain.saveExpenseRecord(edited)
        XCTAssertNil(saved.hustleId)
    }

    // MARK: - Phase C: Synergy bridges

    func testSplitPairCreatesLinkedRows() {
        let primary = Hustle(name: "LLC")
        let secondary = Hustle(name: "Personal")
        let base = ExpenseRecord(
            name: "Software",
            amountValue: -100,
            currencyCode: "USD",
            date: Date(),
            categoryRaw: TransactionCategory.other.rawValue,
            merchantName: "Adobe"
        )

        let pair = SynergyBridgeEngine.makeSplitPair(
            base: base,
            primaryHustleId: primary.id,
            secondaryHustleId: secondary.id,
            secondarySharePercent: 40
        )

        XCTAssertEqual(pair.count, 2)
        XCTAssertEqual(pair[0].bridgeGroupId, pair[1].bridgeGroupId)
        XCTAssertEqual(pair[0].bridgePeerExpenseId, pair[1].id)
        XCTAssertEqual(pair[1].bridgePeerExpenseId, pair[0].id)
        XCTAssertEqual(pair[0].hustleId, primary.id)
        XCTAssertEqual(pair[1].hustleId, secondary.id)
        XCTAssertEqual(abs(pair[0].amountValue), 60)
        XCTAssertEqual(abs(pair[1].amountValue), 40)
    }

    func testDividendTransferPairBalancesWorkspaces() {
        let source = Hustle(name: "LLC")
        let target = Hustle(name: "Personal")

        let pair = SynergyBridgeEngine.makeDividendTransferPair(
            amount: 250,
            currencyCode: "USD",
            date: Date(),
            label: "Owner draw",
            sourceHustleId: source.id,
            targetHustleId: target.id,
            notes: nil
        )

        XCTAssertEqual(pair.count, 2)
        XCTAssertEqual(pair[0].amountValue, -250)
        XCTAssertEqual(pair[1].amountValue, 250)
        XCTAssertEqual(pair[0].bridgeRole, SynergyBridgeRole.transferOut.rawValue)
        XCTAssertEqual(pair[1].bridgeRole, SynergyBridgeRole.transferIn.rawValue)
        XCTAssertEqual(pair[0].hustleId, source.id)
        XCTAssertEqual(pair[1].hustleId, target.id)
    }

    func testSaveBridgeRecordsPersistsBothLegs() throws {
        settings.sideHustleMatrixEnabled = true
        let source = Hustle(name: "LLC")
        let target = Hustle(name: "Personal")
        hustleManager.replaceAll([source, target], selectedId: nil)

        let pair = SynergyBridgeEngine.makeDividendTransferPair(
            amount: 80,
            currencyCode: "USD",
            date: Date(),
            label: "Draw",
            sourceHustleId: source.id,
            targetHustleId: target.id,
            notes: nil
        )

        let saved = try brain.saveBridgeRecords(pair)
        XCTAssertEqual(saved.count, 2)
        let all = try brain.fetchAllExpenseRecords()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.filter { $0.bridgeGroupId != nil }.count, 2)
    }

    func testWorkspaceROISummaryAggregatesTransfers() throws {
        settings.sideHustleMatrixEnabled = true
        let source = Hustle(name: "LLC")
        let target = Hustle(name: "Personal")
        hustleManager.replaceAll([source, target], selectedId: nil)

        _ = try brain.saveBridgeRecords(
            SynergyBridgeEngine.makeDividendTransferPair(
                amount: 100,
                currencyCode: "USD",
                date: Date(),
                label: "Draw A",
                sourceHustleId: source.id,
                targetHustleId: target.id,
                notes: nil
            )
        )
        _ = try brain.saveBridgeRecords(
            SynergyBridgeEngine.makeDividendTransferPair(
                amount: 50,
                currencyCode: "USD",
                date: Date(),
                label: "Draw B",
                sourceHustleId: source.id,
                targetHustleId: target.id,
                notes: nil
            )
        )

        let records = try brain.fetchAllExpenseRecords()
        let summary = WorkspaceROIEngine.summarize(records: records, hustles: hustleManager.hustles)

        XCTAssertEqual(summary.flows.count, 1)
        XCTAssertEqual(summary.flows.first?.totalAmount, 150)
        XCTAssertEqual(summary.flows.first?.eventCount, 2)
    }
}
