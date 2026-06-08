//
//  TaxEnvelopeYearPacketExporter.swift
//  BuxMuse
//

import SwiftUI
import UIKit

enum TaxEnvelopeYearPacketExporter {

    @MainActor
    static func generatePDF(
        context: TaxEnvelopeSourceContext,
        display: TaxEnvelopeRootDisplay
    ) -> Data? {
        let view = TaxEnvelopeYearPacketContentView(context: context, display: display)
            .frame(width: 340)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        return SimpleStudioBusinessCardPDFExporter.generatePDF(from: view)
    }

    static func temporaryFileURL(data: Data, filename: String = "TaxYearSummary.pdf") -> URL? {
        SimpleStudioBusinessCardPDFExporter.temporaryFileURL(data: data, filename: filename)
    }
}

struct TaxEnvelopeYearPacketContentView: View {
    let context: TaxEnvelopeSourceContext
    let display: TaxEnvelopeRootDisplay

    private var quarterly: QuarterlyTaxEstimate {
        TaxEnvelopeEngine.quarterlyEstimate(context: context)
    }

    private var schedule: String { context.taxProfile.paymentSchedule }

    private var locale: Locale { context.locale }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(BuxCatalogLabel.string("My year summary", locale: locale))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text(display.countryLabel)
                .font(.system(size: 14, weight: .semibold))
            if let taxYear = display.taxYearLabel {
                Text(taxYear)
                    .font(.system(size: 12))
            }

            Text(
                BuxLocalizedString.format(
                    "You pay tax: %@",
                    locale: locale,
                    TaxEnvelopePaymentSchedule.localizedScheduleName(schedule, locale: locale)
                )
            )
            .font(.system(size: 12, weight: .medium))

            Divider()

            row(BuxCatalogLabel.string("Gross income (YTD)", locale: locale), format(quarterly.breakdown.totalIncome))
            row(BuxCatalogLabel.string("Deductible expenses", locale: locale), format(quarterly.breakdown.deductibleExpenses))
            row(BuxCatalogLabel.string("Estimated tax", locale: locale), format(quarterly.breakdown.totalEstimatedTax))
            row(BuxCatalogLabel.string("You've set aside", locale: locale), format(TaxEnvelopeEngine.jarSavedTotal(envelope: context.envelope)))
            row(
                TaxEnvelopePaymentSchedule.yearSummaryDueRowTitle(schedule: schedule, locale: locale),
                format(quarterly.totalDue)
            )

            Divider()

            Text(BuxCatalogLabel.string("Appendix — not a tax return", locale: locale))
                .font(.system(size: 11, weight: .bold))
            Text(
                BuxCatalogLabel.string(
                    "Figures are estimates from your BuxMuse books and BuxMuse Intelligence on your device. File with your tax authority or accountant.",
                    locale: locale
                )
            )
            .font(.system(size: 10))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold))
        }
    }

    private func format(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = context.profile.currencyCode
        formatter.locale = locale
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
