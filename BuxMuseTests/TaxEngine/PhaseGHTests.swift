//
//  PhaseGHTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class PhaseGHTests: XCTestCase {

    func testGBFiscalQuarterLabelIsNotCalendarQ1InJune() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let june = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!
        let label = WorldTaxEngine.quarterLabel(countryCode: "GB", reference: june, calendar: calendar)
        XCTAssertTrue(label.hasPrefix("FQ"))
        XCTAssertFalse(label.hasPrefix("Q1 2026"))
    }

    func testUSDefaultQuarterUsesFiscalQuarterPeriod() {
        let period = WorldTaxEngine.defaultQuarterPeriod(countryCode: "US", reference: Date())
        guard case .fiscalQuarter = period else {
            return XCTFail("Expected fiscalQuarter period for catalog-backed US")
        }
    }

    func testCatalogMergePreservesBundledVerifiedWhenRemoteIsEmpty() {
        guard let bundled = TaxComputeCatalogLoader.loadBundled() else {
            return XCTFail("Missing bundled compute catalog")
        }
        let remote = TaxComputeCatalogPayload(
            schemaVersion: 1,
            updatedAt: "2099-01-01T00:00:00Z",
            countries: [
                "ZZ": TaxCountryComputeEntry(
                    meta: TaxCountryComputeMeta(
                        isoCode: "ZZ",
                        currency: "USD",
                        taxYear: "2099",
                        fiscalYearStartMonth: 1,
                        fiscalYearStartDay: 1,
                        coverageTier: .manualOverride,
                        supportedIncomePaths: [],
                        lastVerified: "2099-01-01"
                    ),
                    national: TaxComputeBlock()
                ),
            ]
        )

        let merged = TaxComputeCatalogLoader.mergePreservingBundledVerified(
            remote: remote,
            bundled: bundled
        )

        XCTAssertNotNil(merged.countries["GB"])
        XCTAssertEqual(merged.countries["GB"]?.meta.coverageTier, .verified)
    }

    func testSparklineUsesSubtotalNotInvoiceTotal() {
        let invoice = StudioInvoice(
            clientId: UUID(),
            issueDate: Date(),
            status: .paid,
            subtotal: 100,
            taxAmount: 20,
            total: 120
        )
        let values = TaxStudioChartEngine.taxPressureSparkline(
            invoices: [invoice],
            receipts: [],
            effectiveRate: 0.20,
            months: 1,
            now: Date()
        )
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0], 20, accuracy: 0.01)
    }

    func testDEUsesGenericModuleNotLegacy() {
        let taxProfile = StudioTaxProfile(
            countryCode: "DE",
            vatRegistered: false,
            selectedTaxCountry: "DE"
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "DE"),
            taxProfile: taxProfile,
            invoices: [
                StudioInvoice(clientId: UUID(), status: .paid, subtotal: 30_000, total: 30_000),
            ],
            receipts: []
        )
        let result = WorldTaxEngine.compute(request)
        XCTAssertNotEqual(result.source, .legacyManualRates)
        XCTAssertGreaterThan(result.legacyBreakdown.incomeTax, 0)
    }
}
