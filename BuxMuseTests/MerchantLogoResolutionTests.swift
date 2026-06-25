//
//  MerchantLogoResolutionTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class MerchantLogoResolutionTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "selected_country_id")
        super.tearDown()
    }

    func testSainsburysStatementResolvesUKDomain() {
        UserDefaults.standard.set("GB", forKey: "selected_country_id")
        let domain = MerchantBrandIndex.resolve(
            label: "SAINSBURYS SUPERMARKETS LTD",
            countryISO: "GB"
        )
        XCTAssertEqual(domain, "sainsburys.co.uk")
    }

    func testMercadonaResolvesSpainDomain() {
        UserDefaults.standard.set("ES", forKey: "selected_country_id")
        let domain = MerchantBrandIndex.resolve(label: "MERCADONA VALENCIA", countryISO: "ES")
        XCTAssertEqual(domain, "mercadona.es")
    }

    func testOxxoResolvesMexicoDomain() {
        let domain = MerchantBrandIndex.resolve(label: "OXXO STORE 1234", countryISO: "MX")
        XCTAssertEqual(domain, "oxxo.com")
    }

    func testLaSirenaResolvesDominicanDomain() {
        let domain = MerchantBrandIndex.resolve(
            label: "SUPERMERCADOS LA SIRENA",
            countryISO: "DO"
        )
        XCTAssertEqual(domain, "sirena.do")
    }

    func testUnknownLabelDoesNotSquishToFakeDomain() {
        UserDefaults.standard.set("DO", forKey: "selected_country_id")
        let domain = MerchantDomainResolver.resolveDomain(for: "farmacaribe noise 123")
        XCTAssertNil(domain)
    }

    func testWalletStatementUsesBrandIndexForSainsburys() {
        UserDefaults.standard.set("GB", forKey: "selected_country_id")
        let resolution = WalletStatementIntelligence.resolve(
            rawLabel: "SAINSBURYS SUPERMARKETS",
            contexts: []
        )
        XCTAssertEqual(resolution.domain, "sainsburys.co.uk")
        XCTAssertEqual(resolution.confidence, .high)
    }
}
