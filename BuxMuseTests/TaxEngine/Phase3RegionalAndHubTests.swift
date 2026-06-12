//
//  Phase3RegionalAndHubTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class Phase3RegionalAndHubTests: XCTestCase {

    func testScotlandUsesScottishBracketsAndNationalNI() {
        var taxProfile = StudioTaxProfile(
            countryCode: "GB",
            regionCode: "SCT",
            vatRegistered: false,
            selectedTaxCountry: "GB"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 40_000,
            total: 40_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "GB", regionCode: "SCT", currencyCode: "GBP"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 5_582.82)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 1_645.8)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 7_228.62)
    }

    func testUSCaliforniaAddsStateTaxOnTopOfFederal() {
        guard let entry = TaxComputeCatalogStore.shared.entry(for: "US"),
              let federalRules = entry.national.selfEmployed,
              let stateRules = entry.regionalSelfEmployedRules(forRegion: "CA"),
              !stateRules.brackets.isEmpty else {
            return XCTFail("Missing US/CA catalog rules")
        }

        let taxProfile = StudioTaxProfile(
            countryCode: "US",
            regionCode: "CA",
            selectedTaxCountry: "US"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 50_000,
            total: 50_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "US", regionCode: "CA", currencyCode: "USD"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let taxable: Decimal = 50_000
        let expectedFederal = TaxComputeKernel.progressiveTax(on: taxable, brackets: federalRules.brackets)
        let expectedState = TaxComputeKernel.progressiveTax(on: taxable, brackets: stateRules.brackets)
        let expectedIncome = expectedFederal + expectedState
        let expectedSECA = CountryTaxComputeSupport.usSECA(
            on: taxable,
            rules: federalRules.socialContributions
        ).total

        let result = WorldTaxEngine.compute(request)

        XCTAssertGreaterThan(expectedState, 0)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, expectedIncome)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, expectedSECA)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, expectedIncome + expectedSECA)
    }

    func testUSTexasHasNoStateIncomeTax() {
        var taxProfile = StudioTaxProfile(
            countryCode: "US",
            regionCode: "TX",
            selectedTaxCountry: "US"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 50_000,
            total: 50_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "US", regionCode: "TX", currencyCode: "USD"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.legacyBreakdown.incomeTax, 5_914)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 12_978.775)
    }

    func testGBDefaultHubPeriodUsesFiscalYearToDate() {
        let period = WorldTaxEngine.defaultHubPeriod(countryCode: "GB")
        guard case .fiscalYearToDate = period else {
            return XCTFail("Expected fiscalYearToDate for GB")
        }
    }

    func testUSDefaultHubPeriodUsesFiscalYearToDate() {
        let period = WorldTaxEngine.defaultHubPeriod(countryCode: "US")
        guard case .fiscalYearToDate = period else {
            return XCTFail("Expected fiscalYearToDate for US catalog country")
        }
    }

    func testStudioHubBridgeMatchesWorldTaxEngine() {
        var taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: false,
            selectedTaxCountry: "GB"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 40_000,
            total: 40_000
        )
        let profile = StudioProfile(countryCode: "GB", currencyCode: "GBP")

        let bridge = WorldTaxEngine.incomeTaxBreakdown(
            profile: profile,
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )
        let direct = WorldTaxEngine.compute(
            TaxComputationRequest(
                profile: profile,
                taxProfile: taxProfile,
                invoices: [invoice],
                receipts: [],
                period: WorldTaxEngine.defaultHubPeriod(countryCode: "GB")
            )
        ).legacyBreakdown

        XCTAssertEqual(bridge, direct)
    }
}
