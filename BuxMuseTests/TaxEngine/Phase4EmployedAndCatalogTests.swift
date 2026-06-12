//
//  Phase4EmployedAndCatalogTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class Phase4EmployedAndCatalogTests: XCTestCase {

    func testUSEmployedHypotheticalSkipsSECA() {
        let taxProfile = StudioTaxProfile(
            countryCode: "US",
            selectedTaxCountry: "US",
            taxIncomeType: .employed
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 50_000,
            total: 50_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "US", currencyCode: "USD"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: [],
            incomePath: .employedHypothetical
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 5_914)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 0)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 5_914)
    }

    func testGBEmployedHypotheticalUsesClass1NI() {
        let taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: false,
            selectedTaxCountry: "GB",
            taxIncomeType: .employed
        )
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
            receipts: [],
            incomePath: .employedHypothetical
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.legacyBreakdown.incomeTax, 5_486)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 2_194.4)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 7_680.4)
    }

    @MainActor
    func testComputeCatalogStoreLoadsBundledPayload() async {
        await TaxComputeCatalogStore.shared.ensureCatalogLoaded(force: true)
        XCTAssertNotNil(TaxComputeCatalogStore.shared.payload)
        XCTAssertFalse(TaxComputeCatalogStore.shared.regions(for: "US").isEmpty)
        XCTAssertFalse(TaxComputeCatalogStore.shared.regions(for: "GB").isEmpty)
    }

    func testHydratorRespectsRegionCode() {
        var profile = StudioTaxProfile(countryCode: "GB", selectedTaxCountry: "GB")
        TaxCatalogProfileHydrator.applyCatalogRules(to: &profile, countryCode: "GB", regionCode: "SCT")

        XCTAssertFalse(profile.incomeTaxRules.isEmpty)
        XCTAssertGreaterThan(profile.incomeTaxRules[0].rate, 0.18)
    }
}
