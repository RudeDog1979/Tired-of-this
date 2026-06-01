//
//  SideHustleMatrixTests.swift
//  BuxMuseTests
//

import XCTest
import Combine
@testable import BuxMuse

@MainActor
final class SideHustleMatrixTests: XCTestCase {
    var settings: SettingsStore!
    var hustleManager: HustleManager!
    var localEngine: LocalFinancialIntelligenceEngine18!

    override func setUp() {
        super.setUp()
        settings = SettingsStore.shared
        settings.resetAllData()

        UserDefaults.standard.removeObject(forKey: "buxmuse.sidehustles.list")
        UserDefaults.standard.removeObject(forKey: "buxmuse.sidehustles.selectedId")
        UserDefaults.standard.set(false, forKey: "buxmuse.sidehustle.enabled")
        UserDefaults.standard.set(true, forKey: "buxmuse.sidehustle.showUnassigned")

        hustleManager = HustleManager.shared
        hustleManager.loadHustles()
        hustleManager.selectHustle(nil)

        settings.sideHustleMatrixEnabled = true
        _ = hustleManager.addHustle(name: "Main Business", colorHex: "#5A55F5")

        localEngine = LocalFinancialIntelligenceEngine18()
    }

    override func tearDown() {
        settings.sideHustleMatrixEnabled = false
        settings.resetAllData()
        hustleManager.selectHustle(nil)

        UserDefaults.standard.removeObject(forKey: "buxmuse.sidehustles.list")
        UserDefaults.standard.removeObject(forKey: "buxmuse.sidehustles.selectedId")
        UserDefaults.standard.set(false, forKey: "buxmuse.sidehustle.enabled")

        settings = nil
        hustleManager = nil
        localEngine = nil
        super.tearDown()
    }

    func testMatrixOffByDefaultDoesNotFilter() {
        settings.sideHustleMatrixEnabled = false
        let hustleAId = UUID()
        let tx = Transaction(
            id: UUID(),
            date: Date(),
            amount: MoneyAmount(value: -10, currencyCode: "USD"),
            merchantName: "Test",
            category: .other,
            hustleId: hustleAId
        )
        localEngine.loadTransactions([tx])
        hustleManager.selectHustle(hustleAId)
        XCTAssertEqual(localEngine.allTransactions().count, 1)
    }

    func testFreeTierHustleLimit() {
        settings.studioMode = .simple

        XCTAssertEqual(hustleManager.activeHustlesCount, 1)
        XCTAssertTrue(hustleManager.canAddHustle())

        XCTAssertTrue(hustleManager.addHustle(name: "Photography", colorHex: "#FF5E5B"))
        XCTAssertEqual(hustleManager.activeHustlesCount, 2)
        XCTAssertTrue(hustleManager.canAddHustle())

        XCTAssertTrue(hustleManager.addHustle(name: "Consulting", colorHex: "#30D158"))
        XCTAssertEqual(hustleManager.activeHustlesCount, 3)

        XCTAssertFalse(hustleManager.canAddHustle())
        XCTAssertFalse(hustleManager.addHustle(name: "Copywriting", colorHex: "#9C27B0"))
        XCTAssertEqual(hustleManager.activeHustlesCount, 3)
    }

    func testProTierHustleUnlimited() {
        settings.studioMode = .pro

        XCTAssertTrue(hustleManager.addHustle(name: "Gig A", colorHex: "#FF5E5B"))
        XCTAssertTrue(hustleManager.addHustle(name: "Gig B", colorHex: "#30D158"))
        XCTAssertTrue(hustleManager.addHustle(name: "Gig C", colorHex: "#9C27B0"))
        XCTAssertTrue(hustleManager.addHustle(name: "Gig D", colorHex: "#00E5FF"))

        XCTAssertEqual(hustleManager.activeHustlesCount, 5)
        XCTAssertTrue(hustleManager.canAddHustle())
    }

    func testLedgerContextSegregation() {
        settings.showUnassignedExpensesInWorkspace = false

        let hustleAId = UUID()
        let hustleBId = UUID()

        let tx1 = Transaction(
            id: UUID(),
            date: Date(),
            amount: MoneyAmount(value: -150.00, currencyCode: "USD"),
            merchantName: "Adobe Creative",
            category: .subscriptions,
            hustleId: hustleAId
        )

        let tx2 = Transaction(
            id: UUID(),
            date: Date().addingTimeInterval(-3600),
            amount: MoneyAmount(value: -50.00, currencyCode: "USD"),
            merchantName: "AWS Cloud",
            category: .subscriptions,
            hustleId: hustleAId
        )

        let tx3 = Transaction(
            id: UUID(),
            date: Date().addingTimeInterval(-7200),
            amount: MoneyAmount(value: -200.00, currencyCode: "USD"),
            merchantName: "Uber Business",
            category: .travel,
            hustleId: hustleBId
        )

        let unassigned = Transaction(
            id: UUID(),
            date: Date().addingTimeInterval(-10800),
            amount: MoneyAmount(value: -25.00, currencyCode: "USD"),
            merchantName: "Coffee Shop",
            category: .restaurants,
            hustleId: nil
        )

        localEngine.loadTransactions([tx1, tx2, tx3, unassigned])

        hustleManager.selectHustle(nil)
        XCTAssertEqual(localEngine.allTransactions().count, 4)

        hustleManager.selectHustle(hustleAId)
        let txsA = localEngine.allTransactions()
        XCTAssertEqual(txsA.count, 2)
        XCTAssertTrue(txsA.contains(where: { $0.merchantName == "Adobe Creative" }))

        settings.showUnassignedExpensesInWorkspace = true
        let txsAWithUnassigned = localEngine.allTransactions()
        XCTAssertEqual(txsAWithUnassigned.count, 3)
        XCTAssertTrue(txsAWithUnassigned.contains(where: { $0.merchantName == "Coffee Shop" }))
    }
}
