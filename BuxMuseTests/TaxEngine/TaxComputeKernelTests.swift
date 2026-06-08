//
//  TaxComputeKernelTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class TaxComputeKernelTests: XCTestCase {

    func testProgressiveTaxGBBasicBand() {
        let brackets = [
            TaxComputeBracket(from: 0, to: 37_700, rate: 0.20),
            TaxComputeBracket(from: 37_700, to: 112_570, rate: 0.40),
            TaxComputeBracket(from: 112_570, rate: 0.45),
        ]
        let tax = TaxComputeKernel.progressiveTax(on: 30_000, brackets: brackets)
        XCTAssertEqual(tax, 6_000)
    }

    func testProgressiveTaxZeroAmount() {
        let brackets = [TaxComputeBracket(from: 0, to: 10_000, rate: 0.20)]
        XCTAssertEqual(TaxComputeKernel.progressiveTax(on: 0, brackets: brackets), 0)
    }

    func testTaxableAfterAllowance() {
        let taxable = TaxComputeKernel.taxableAfterAllowance(
            gross: 50_000,
            deductions: 5_000,
            personalAllowance: 12_570
        )
        XCTAssertEqual(taxable, 32_430)
    }

    func testIndirectTaxNetWhenRegistered() {
        XCTAssertEqual(
            TaxComputeKernel.indirectTaxNet(
                invoiceTaxCollected: 2_000,
                receiptTaxPaid: 500,
                registered: true
            ),
            1_500
        )
    }

    func testIndirectTaxNetWhenNotRegistered() {
        XCTAssertEqual(
            TaxComputeKernel.indirectTaxNet(
                invoiceTaxCollected: 2_000,
                receiptTaxPaid: 500,
                registered: false
            ),
            0
        )
    }

    func testWorldTaxEngineMatchesLegacyBreakdownForUnknownCountry() {
        var taxProfile = StudioTaxProfile()
        taxProfile.estimatedIncomeTaxRatePercent = 20
        taxProfile.estimatedSelfEmployedRatePercent = 10
        taxProfile.selectedTaxCountry = "JP"

        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 10_000,
            total: 10_000
        )

        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "JP"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 3_000)
        XCTAssertEqual(result.totalTax, 3_000)
        XCTAssertEqual(result.source, .legacyManualRates)
        XCTAssertEqual(result.coverageTier, .manualOverride)
    }

    func testComputeCatalogLoadsTier1Countries() {
        let payload = TaxComputeCatalogLoader.loadBundled()
        XCTAssertNotNil(payload)
        XCTAssertNotNil(payload?.countries["GB"])
        XCTAssertNotNil(payload?.countries["US"])
        XCTAssertNotNil(payload?.countries["ES"])
        XCTAssertNotNil(payload?.countries["DO"])
        XCTAssertNotNil(payload?.countries["FR"])
        XCTAssertNotNil(payload?.countries["PL"])
        XCTAssertEqual(payload?.countries["GB"]?.meta.coverageTier, .verified)
    }
}
