//
//  PhasesCDEFTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class PhasesCDEFTests: XCTestCase {

    // MARK: - Phase C

    func testUSClientRegionAddsStateTaxLine() {
        let rates = InvoiceRegionalTaxResolver.supplementalRates(
            countryCode: "US",
            clientRegionCode: "CA",
            locale: Locale(identifier: "en_GB")
        )
        XCTAssertEqual(rates.count, 1)
        XCTAssertGreaterThan(rates.first?.percentage ?? 0, 0)
    }

    func testUSClientRegionTexasHasSalesTaxLine() {
        let rates = InvoiceRegionalTaxResolver.supplementalRates(
            countryCode: "US",
            clientRegionCode: "TX",
            locale: Locale(identifier: "en_GB")
        )
        XCTAssertEqual(rates.count, 1)
        XCTAssertGreaterThan(rates.first?.percentage ?? 0, 0)
    }

    func testTaxProfileConfigIncludesRegionalRates() {
        var settings = StudioInvoiceSettings()
        settings.defaultInvoiceTaxSource = .taxProfile

        let taxProfile = StudioTaxProfile(
            countryCode: "US",
            vatRegistered: true,
            selectedTaxCountry: "US"
        )

        let config = InvoiceTaxProfileResolver.config(
            taxProfile: taxProfile,
            settings: settings,
            source: .taxProfile,
            clientRegionCode: "NY",
            locale: Locale(identifier: "en_GB")
        )

        XCTAssertEqual(config.rates.count, 1)
        XCTAssertTrue(config.rates.first?.label.contains("tax") ?? false)
    }

    // MARK: - Phase D

    func testReducedLineItemHalvesTaxableBase() {
        let items = [
            StudioInvoiceLineItem(description: "Full", unitPrice: 100, taxCategory: .standard),
            StudioInvoiceLineItem(description: "Meal", unitPrice: 100, taxCategory: .reduced),
            StudioInvoiceLineItem(description: "Free", unitPrice: 100, taxCategory: .exempt),
        ]
        let weighted = InvoiceLineTaxMath.weightedTaxableSum(items: items)
        XCTAssertEqual(weighted, 150)
    }

    func testCatalogMealsDeductibilityIsFiftyPercent() {
        let rules = [
            DeductionCategoryRule(categoryId: "meals", name: "Meals", deductibilityType: .partial),
            DeductionCategoryRule(categoryId: "travel", name: "Travel", deductibilityType: .full),
        ]
        let mealReceipt = StudioReceipt(
            amount: 100,
            merchant: "Cafe",
            category: "Business meals",
            isDeductible: true,
            isBusiness: true,
            deductiblePercentage: 100
        )
        let travelReceipt = StudioReceipt(
            amount: 200,
            merchant: "Rail",
            category: "Travel",
            isDeductible: true,
            isBusiness: true,
            deductiblePercentage: 100
        )

        XCTAssertEqual(StudioDeductionMath.deductibleAmount(for: mealReceipt, catalogRules: rules), 50)
        XCTAssertEqual(StudioDeductionMath.deductibleAmount(for: travelReceipt, catalogRules: rules), 200)
    }

    // MARK: - Phase E

    func testStructuredGermanyUsesGenericModule() {
        let profile = StudioProfile(businessName: "Test", countryCode: "DE")
        let taxProfile = StudioTaxProfile(
            countryCode: "DE",
            vatRegistered: false,
            selectedTaxCountry: "DE"
        )
        let request = TaxComputationRequest(
            profile: profile,
            taxProfile: taxProfile,
            invoices: [
                StudioInvoice(
                    clientId: UUID(),
                    status: .paid,
                    subtotal: 50_000,
                    taxAmount: 0,
                    total: 50_000
                ),
            ],
            receipts: [],
            incomePath: .selfEmployed
        )

        let result = WorldTaxEngine.compute(request)
        XCTAssertEqual(result.countryCode, "DE")
        XCTAssertEqual(result.coverageTier, TaxCoverageTier.structured)
        XCTAssertEqual(result.source, TaxComputationSource.structuredCatalog)
        XCTAssertGreaterThan(result.legacyBreakdown.incomeTax, 0)
    }

    // MARK: - Phase F

    func testGBHidesManualIncomeRateWhenCatalogBracketsExist() {
        var profile = StudioTaxProfile(
            countryCode: "GB",
            selectedTaxCountry: "GB"
        )
        TaxCatalogProfileHydrator.applyCatalogRules(to: &profile, countryCode: "GB")
        XCTAssertFalse(TaxCatalogProfileHydrator.shouldShowManualIncomeRate(for: profile))
        XCTAssertFalse(TaxCatalogProfileHydrator.shouldShowManualIndirectRate(for: profile))
    }

    func testCustomProfileShowsManualRates() {
        let profile = StudioTaxProfile(countryCode: "CUSTOM", selectedTaxCountry: nil)
        XCTAssertTrue(TaxCatalogProfileHydrator.shouldShowManualIncomeRate(for: profile))
        XCTAssertTrue(TaxCatalogProfileHydrator.shouldShowManualIndirectRate(for: profile))
    }
}
