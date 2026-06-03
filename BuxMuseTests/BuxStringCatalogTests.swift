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
        let locale = BuxInterfaceLocale.locale(forCountryID: "AR")
        XCTAssertEqual(BuxStringCatalog.resourceTag(for: locale), "es-419")
        XCTAssertEqual(BuxStringCatalog.localized("Custom", locale: locale), "Personalizado")
    }
}
