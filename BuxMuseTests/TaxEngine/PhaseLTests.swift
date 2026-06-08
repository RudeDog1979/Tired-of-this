//
//  PhaseLTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class PhaseLTests: XCTestCase {

    func testCaliforniaUsesCatalogSalesTaxNotIncomeProxy() {
        let rates = InvoiceRegionalTaxResolver.supplementalRates(
            countryCode: "US",
            clientRegionCode: "CA",
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(rates.count, 1)
        XCTAssertEqual(rates.first?.percentage, 7.25)
        XCTAssertTrue(rates.first?.label.lowercased().contains("sales tax") ?? false)
    }

    func testTexasUsesStateSalesTaxRate() {
        let rates = InvoiceRegionalTaxResolver.supplementalRates(
            countryCode: "US",
            clientRegionCode: "TX",
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(rates.count, 1)
        XCTAssertEqual(rates.first?.percentage, 6.25)
    }

    func testBundledUSRegionalSalesTaxRatesDecode() {
        guard let entry = TaxComputeCatalogStore.shared.entry(for: "US") else {
            return XCTFail("Missing US catalog entry")
        }
        XCTAssertEqual(entry.regionalSalesTaxRate(forRegion: "CA"), 0.0725)
        XCTAssertEqual(entry.regionalSalesTaxRate(forRegion: "NY"), 0.04)
        XCTAssertEqual(entry.regionalSalesTaxRate(forRegion: "TX"), 0.0625)
        XCTAssertEqual(entry.regionalSalesTaxRate(forRegion: "FL"), 0.06)
    }
}
