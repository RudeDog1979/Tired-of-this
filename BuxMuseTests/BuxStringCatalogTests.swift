//
//  BuxStringCatalogTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class BuxStringCatalogTests: XCTestCase {
    func testLatinAmericanSpanishResolvesFromCatalog() {
        let locale = Locale(identifier: "es-419")
        let value = BuxStringCatalog.localized("Expenses", locale: locale)
        XCTAssertEqual(value, "Gastos")
    }

    func testEnglishReturnsSourceKey() {
        let locale = Locale(identifier: "en")
        let value = BuxStringCatalog.localized("Expenses", locale: locale)
        XCTAssertEqual(value, "Expenses")
    }

    func testArgentinaCountryMapsToEs419() {
        guard let country = CountryCatalog.country(for: "AR") else {
            XCTFail("Could not load country setting for AR")
            return
        }
        let locale = BuxInterfaceLocale.locale(for: country)
        XCTAssertEqual(BuxStringCatalog.resourceTag(for: locale), "es-419")
        XCTAssertEqual(BuxStringCatalog.localized("Custom", locale: locale), "Personalizado")
    }
}
