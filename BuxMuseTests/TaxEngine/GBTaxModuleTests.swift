//
//  GBTaxModuleTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class GBTaxModuleTests: XCTestCase {

    func testGBProgressiveIncomeAndClass4NI() {
        var taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: false,
            selectedTaxCountry: "GB"
        )
        taxProfile.incomeTaxRules = [
            TaxBracketRule(lowerBound: 0, upperBound: 37_700, rate: 0.20),
        ]

        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 40_000,
            total: 40_000
        )

        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "GB", currencyCode: "GBP"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.countryCode, "GB")
        XCTAssertEqual(result.legacyBreakdown.totalIncome, 40_000)
        XCTAssertEqual(result.legacyBreakdown.taxableIncome, 27_430)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 5_486)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 1_645.8)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 7_131.8)
    }

    func testCatalogHydratorPopulatesGBRules() {
        var profile = StudioTaxProfile(countryCode: "GB", selectedTaxCountry: "GB")
        TaxCatalogProfileHydrator.applyCatalogRules(to: &profile, countryCode: "GB")

        XCTAssertFalse(profile.incomeTaxRules.isEmpty)
        XCTAssertEqual(
            TaxCatalogProfileHydrator.catalogPaymentSchedule(countryCode: "GB"),
            "quarterly"
        )
        XCTAssertFalse(profile.vatRules.isEmpty)
        XCTAssertEqual(profile.vatRules.first?.rate, 0.20)
        XCTAssertFalse(profile.deductionCategories.isEmpty)
    }
}
