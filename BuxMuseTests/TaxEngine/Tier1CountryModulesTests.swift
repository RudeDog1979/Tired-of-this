//
//  Tier1CountryModulesTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class Tier1CountryModulesTests: XCTestCase {

    // MARK: - US

    func testUSFederalProgressiveAndSECA() {
        let taxProfile = StudioTaxProfile(
            countryCode: "US",
            vatRegistered: false,
            selectedTaxCountry: "US"
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
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 5_914)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 7_064.775)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 12_978.775)
    }

    // MARK: - ES

    func testESProgressiveAndAutonomoSocial() {
        let taxProfile = StudioTaxProfile(
            countryCode: "ES",
            selectedTaxCountry: "ES"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 30_000,
            total: 30_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "ES", currencyCode: "EUR"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 7_165.5)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 9_000)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 16_165.5)
    }

    // MARK: - DO (Dominican Republic)

    func testDOProgressiveISRAndAdvancePayments() {
        let taxProfile = StudioTaxProfile(
            countryCode: "DO",
            selectedTaxCountry: "DO"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 500_000,
            total: 500_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "DO", currencyCode: "DOP"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 12_567)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 7_500)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 20_067)
    }

    // MARK: - FR

    func testFRProgressiveAndURSSAF() {
        let taxProfile = StudioTaxProfile(
            countryCode: "FR",
            selectedTaxCountry: "FR"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 40_000,
            total: 40_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "FR", currencyCode: "EUR"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 5_286.23)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 8_800)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 14_086.23)
    }

    // MARK: - PL

    func testPLFlatScaleAndZUS() {
        let taxProfile = StudioTaxProfile(
            countryCode: "PL",
            selectedTaxCountry: "PL"
        )
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 80_000,
            total: 80_000
        )
        let request = TaxComputationRequest(
            profile: StudioProfile(countryCode: "PL", currencyCode: "PLN"),
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: []
        )

        let result = WorldTaxEngine.compute(request)

        XCTAssertEqual(result.source, TaxComputationSource.countryModule)
        XCTAssertEqual(result.legacyBreakdown.incomeTax, 9_600)
        XCTAssertEqual(result.legacyBreakdown.selfEmployedTax, 15_200)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 24_800)
    }

    // MARK: - Legacy fallback

    func testUnknownCountryFallsBackToLegacyManualRates() {
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
        XCTAssertEqual(result.source, .legacyManualRates)
        XCTAssertEqual(result.legacyBreakdown.totalEstimatedTax, 3_000)
        XCTAssertEqual(result.coverageTier, .manualOverride)
    }
}
