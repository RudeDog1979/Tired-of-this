//
//  InvoiceTaxProfileResolverTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class InvoiceTaxProfileResolverTests: XCTestCase {

    func testTaxProfileSourceUsesCatalogVATRate() {
        var settings = StudioInvoiceSettings()
        settings.defaultInvoiceTaxSource = .taxProfile

        let taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: true,
            vatRules: [VatRule(rate: 0.20)],
            selectedTaxCountry: "GB",
            customIndirectTax: "Standard rate 20%"
        )

        let config = InvoiceTaxProfileResolver.config(
            taxProfile: taxProfile,
            settings: settings,
            source: .taxProfile
        )

        XCTAssertEqual(config.source, .taxProfile)
        XCTAssertEqual(config.rates.count, 1)
        XCTAssertEqual(config.rates.first?.percentage, 20)
        XCTAssertEqual(config.rates.first?.label, "VAT")
    }

    func testNotRegisteredProducesNoRates() {
        let taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: false,
            vatRules: [VatRule(rate: 0.20)],
            selectedTaxCountry: "GB",
            customIndirectTax: "Standard rate 20%"
        )

        let config = InvoiceTaxProfileResolver.config(
            taxProfile: taxProfile,
            settings: StudioInvoiceSettings(),
            source: .taxProfile
        )

        XCTAssertTrue(config.rates.isEmpty)
    }

    func testSyncClearsRateWhenNotRegistered() {
        var settings = StudioInvoiceSettings(defaultTaxRatePercent: 20)
        let taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: false,
            selectedTaxCountry: "GB"
        )

        InvoiceTaxProfileResolver.syncInvoiceSettings(
            taxProfile: taxProfile,
            settings: &settings
        )

        XCTAssertEqual(settings.defaultInvoiceTaxSource, .taxProfile)
        XCTAssertEqual(settings.defaultTaxBehavior, .noTax)
        XCTAssertNil(settings.defaultTaxRatePercent)
    }

    func testUserIndirectOverrideWins() {
        let taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: true,
            vatRules: [VatRule(rate: 0.20)],
            selectedTaxCountry: "GB",
            customIndirectTax: "VAT",
            estimatedIndirectTaxRatePercent: 5
        )

        let config = InvoiceTaxProfileResolver.config(
            taxProfile: taxProfile,
            settings: StudioInvoiceSettings(),
            source: .taxProfile
        )

        XCTAssertEqual(config.rates.first?.percentage, 5)
    }
}
