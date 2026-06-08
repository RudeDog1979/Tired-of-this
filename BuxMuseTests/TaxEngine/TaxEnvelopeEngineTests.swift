//
//  TaxEnvelopeEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class TaxEnvelopeEngineTests: XCTestCase {

    override func setUp() async throws {
        await TaxComputeCatalogStore.shared.ensureCatalogLoaded(force: true)
    }

    func testUSSetAsideUsesCatalogNotHardcodedFifteenPercent() {
        var taxProfile = StudioTaxProfile()
        taxProfile.taxIncomeType = .selfEmployed
        taxProfile.selectedTaxCountry = "US"
        taxProfile.countryCode = "US"
        taxProfile.paymentSchedule = "quarterly"

        let context = TaxEnvelopeSourceContext(
            profile: StudioProfile(countryCode: "US", currencyCode: "USD"),
            taxProfile: taxProfile,
            proInvoices: [],
            proReceipts: [],
            simpleEntries: [
                SimpleStudioEntry(kind: .income, amount: 10_000, createdAt: Date())
            ],
            envelope: TaxEnvelopeState(isEnabled: true, onboardingCompleted: true)
        )

        let result = TaxEnvelopeEngine.setAsideForIncome(grossIncome: 1_000, context: context)
        XCTAssertGreaterThan(result.rateFraction, 0)
        XCTAssertNotEqual(result.rateFraction, Decimal(0.15))
        XCTAssertGreaterThan(result.amount, 0)
    }

    func testPaymentScheduleReadsUSCatalogCalendar() async throws {
        guard let entry = TaxComputeCatalogStore.shared.entry(for: "US") else {
            return XCTFail("Missing US catalog entry")
        }
        XCTAssertNotNil(entry.national.paymentCalendar)

        let due = TaxEnvelopePaymentSchedule.nextPaymentDate(
            countryCode: "US",
            regionCode: nil,
            schedule: "quarterly",
            reference: Date(timeIntervalSince1970: 1_704_067_200) // Jan 2024
        )
        XCTAssertNotNil(due)
        let month = Calendar.current.component(.month, from: due!)
        XCTAssertTrue([1, 4, 6, 9].contains(month))
    }

    func testSimpleEntriesMergeIntoComputation() {
        let entry = SimpleStudioEntry(kind: .income, amount: 500, createdAt: Date())
        let invoices = TaxEnvelopeContextBridge.mergedInvoices(
            pro: [],
            simpleEntries: [entry],
            periodStart: nil,
            periodEnd: nil
        )
        XCTAssertEqual(invoices.count, 1)
        XCTAssertEqual(invoices[0].subtotal, 500)
    }

    func testTaxTileUsesEnvelopeRateWhenEnabled() {
        var envelope = TaxEnvelopeState()
        envelope.isEnabled = true
        envelope.onboardingCompleted = true

        var taxProfile = StudioTaxProfile()
        taxProfile.taxIncomeType = .selfEmployed
        taxProfile.selectedTaxCountry = "GB"
        taxProfile.countryCode = "GB"

        let context = TaxEnvelopeSourceContext(
            profile: StudioProfile(countryCode: "GB", currencyCode: "GBP"),
            taxProfile: taxProfile,
            proInvoices: [],
            proReceipts: [],
            envelope: envelope
        )

        let legacy = TaxEnvelopeEngine.taxTileMightOwe(made: 1_000, spent: 200, context: nil)
        let catalog = TaxEnvelopeEngine.taxTileMightOwe(made: 1_000, spent: 200, context: context)
        XCTAssertEqual(legacy, 120) // 15% of 800
        XCTAssertNotEqual(catalog, legacy)
    }
}
