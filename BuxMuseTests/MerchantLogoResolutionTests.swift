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

    func testDominosPizzaResolvesUKDomainWithoutHardcoding() {
        UserDefaults.standard.set("GB", forKey: "selected_country_id")
        let domain = MerchantDomainResolver.resolveDomain(for: "Domino's Pizza")
        XCTAssertEqual(domain, "dominos.co.uk")
    }

    func testDominosPossessiveNormalizesWithSpace() {
        let normalized = MerchantLogoEngine.normalizeMerchantName("Domino's Pizza")
        XCTAssertEqual(normalized, "dominos pizza")
    }

    func testPayPalTickerPYPLResolvesDomain() {
        XCTAssertEqual(MerchantAliasIndex.domain(for: "PYPL"), "paypal.com")
        XCTAssertEqual(MerchantDomainResolver.resolveDomain(for: "PYPL"), "paypal.com")
    }

    func testDominoPizzaMiltonResolvesUKDomain() {
        UserDefaults.standard.set("GB", forKey: "selected_country_id")
        let domain = MerchantDomainResolver.resolveDomain(for: "Domino Pizza Milton")
        XCTAssertEqual(domain, "dominos.co.uk")
    }

    func testDominoPizzaMiltonCandidatesStripLocation() {
        let tokens = MerchantLabelParser.brandTokens(from: "Domino Pizza Milton")
        XCTAssertEqual(tokens, ["domino", "pizza"])
    }

    func testConsonantSkeletonPayPal() {
        XCTAssertEqual(MerchantAliasIndex.consonantSkeleton("PayPal"), "pypl")
    }

    func testMangledAmazonCompactResolvesDomain() {
        UserDefaults.standard.set("GB", forKey: "selected_country_id")
        XCTAssertEqual(MerchantBrandIndex.embeddedBrandToken(in: "nq82famazon"), "amazon")
        XCTAssertEqual(MerchantDomainResolver.resolveDomain(for: "NQ82FAMAZON"), "amazon.co.uk")
    }

    func testRobloxCorpCompactResolvesDomain() {
        XCTAssertEqual(MerchantBrandIndex.embeddedBrandToken(in: "robloxcorp"), "roblox")
        XCTAssertEqual(MerchantDomainResolver.resolveDomain(for: "ROBLOXCORP"), "roblox.com")
    }

    func testPayPalFullNameResolvesDomain() {
        XCTAssertEqual(MerchantDomainResolver.resolveDomain(for: "PayPal"), "paypal.com")
    }
}
