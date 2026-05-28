//
//  TaxStudioEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class TaxStudioEngineTests: XCTestCase {
    func testIntelligenceRespectsUserRateOverrides() {
        var taxProfile = StudioTaxProfile()
        taxProfile.estimatedIncomeTaxRatePercent = 20
        taxProfile.estimatedSelfEmployedRatePercent = 10

        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 10_000,
            total: 10_000
        )
        let ctx = TaxStudioContext(
            profile: StudioProfile(),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let intel = TaxIntelligenceEngine.compute(ctx)
        XCTAssertEqual(intel.breakdown.taxableIncome, 10_000)
        XCTAssertEqual(intel.breakdown.totalEstimatedTax, 3_000)
    }

    func testHealthScoreWithinBounds() {
        let ctx = TaxStudioContext(
            profile: StudioProfile(),
            taxProfile: StudioTaxProfile(),
            invoices: [],
            receipts: []
        )
        let intel = TaxIntelligenceEngine.compute(ctx)
        let sanity = TaxSanityCheckEngine.compute(ctx)
        let health = TaxHealthScoreEngine.compute(ctx, intelligence: intel, sanity: sanity)
        XCTAssertGreaterThanOrEqual(health.score, 0)
        XCTAssertLessThanOrEqual(health.score, 100)
    }

    func testOrchestratorProducesTimeline() {
        let ctx = TaxStudioContext(
            profile: StudioProfile(),
            taxProfile: StudioTaxProfile(),
            invoices: [],
            receipts: []
        )
        let snapshot = TaxStudioOrchestrator.buildSnapshot(ctx)
        XCTAssertFalse(snapshot.timeline.isEmpty)
    }
}
