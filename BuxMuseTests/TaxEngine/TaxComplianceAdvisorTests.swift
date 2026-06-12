//
//  TaxComplianceAdvisorTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class TaxComplianceAdvisorTests: XCTestCase {

    func testWarnsWhenInvoicesHaveTaxButProfileNotRegistered() {
        let profile = StudioTaxProfile(countryCode: "GB", vatRegistered: false, selectedTaxCountry: "GB")
        let invoice = StudioInvoice(
            clientId: UUID(),
            status: .paid,
            subtotal: 1000,
            taxAmount: 200,
            total: 1200
        )
        let notices = TaxComplianceAdvisor.notices(
            taxProfile: profile,
            invoices: [invoice]
        )
        XCTAssertTrue(notices.contains { $0.id == "invoice-vat-unregistered" })
    }

    func testIdentitySummaryIncludesRegistrationState() {
        let profile = StudioTaxProfile(
            countryCode: "GB",
            vatRegistered: true,
            selectedTaxCountry: "GB",
            customIndirectTax: "Standard rate 20%"
        )
        let summary = TaxComplianceAdvisor.identitySummary(
            taxProfile: profile,
            locale: Locale(identifier: "en")
        )
        XCTAssertTrue(summary.contains("GB"))
    }
}
