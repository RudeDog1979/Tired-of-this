//
//  PhasesIJTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class PhasesIJTests: XCTestCase {

    // MARK: - Phase I

    func testCatalogPickerOptionsUseTaxProfileRules() {
        let rules = [
            DeductionCategoryRule(categoryId: "meals", name: "Meals", deductibilityType: .partial),
            DeductionCategoryRule(categoryId: "travel", name: "Travel", deductibilityType: .full),
        ]
        let options = ReceiptDeductionCategoryResolver.pickerOptions(catalogRules: rules)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options.first?.deductibilityPercent, 50)
        XCTAssertEqual(options.last?.deductibilityPercent, 100)
    }

    func testSuggestedCategoryMapsSoftwareMerchant() {
        let rules = [
            DeductionCategoryRule(categoryId: "software", name: "Software", deductibilityType: .full),
            DeductionCategoryRule(categoryId: "meals", name: "Meals", deductibilityType: .partial),
        ]
        let category = ReceiptDeductionCategoryResolver.suggestedCategory(
            merchant: "Adobe Creative Cloud",
            catalogRules: rules
        )
        XCTAssertTrue(category.lowercased().contains("software"))
    }

    func testCatalogHintUsesPartialDeductibilityNote() {
        let rules = [
            DeductionCategoryRule(categoryId: "meals", name: "Meals", deductibilityType: .partial),
        ]
        let hint = ReceiptDeductionCategoryResolver.hint(
            for: "Meals",
            catalogRules: rules,
            countryCode: "GB"
        )
        XCTAssertEqual(hint.strength, .medium)
        XCTAssertTrue(hint.note.contains("50%"))
    }

    // MARK: - Phase J

    func testIncomeTaxDisplayIncludesCatalogDetailLines() {
        var taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: false,
            selectedTaxCountry: "GB"
        )
        TaxCatalogProfileHydrator.applyCatalogRules(to: &taxProfile, countryCode: "GB")

        let profile = StudioProfile(countryCode: "GB")
        let invoice = StudioInvoice(
            clientId: UUID(),
            issueDate: Date(),
            status: .paid,
            subtotal: 50_000,
            taxAmount: 0,
            total: 50_000
        )

        let display = IncomeTaxDisplayBuilder.build(
            profile: profile,
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: [],
            mileageEntries: [],
            mileageRatePerUnit: 0,
            format: { "\($0)" },
            locale: Locale(identifier: "en_GB")
        )

        XCTAssertTrue(display.usesCatalogEngine)
        XCTAssertFalse(display.detailLines.isEmpty)
        XCTAssertNotEqual(display.netAfterTaxFormatted, "—")
        XCTAssertTrue(display.periodLabel.contains("Fiscal year") || display.periodLabel.contains("fiscal"))
    }

    func testIncomeTaxDisplayShowsMarginalRateForGB() {
        var taxProfile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: false,
            selectedTaxCountry: "GB"
        )
        TaxCatalogProfileHydrator.applyCatalogRules(to: &taxProfile, countryCode: "GB")

        let profile = StudioProfile(countryCode: "GB")
        let invoice = StudioInvoice(
            clientId: UUID(),
            issueDate: Date(),
            status: .paid,
            subtotal: 60_000,
            taxAmount: 0,
            total: 60_000
        )

        let display = IncomeTaxDisplayBuilder.build(
            profile: profile,
            taxProfile: taxProfile,
            invoices: [invoice],
            receipts: [],
            mileageEntries: [],
            mileageRatePerUnit: 0,
            format: { "\($0)" },
            locale: Locale(identifier: "en_GB")
        )

        XCTAssertNotNil(display.marginalRatePercent)
        XCTAssertGreaterThan(display.marginalRatePercent ?? 0, 0)
    }
}
