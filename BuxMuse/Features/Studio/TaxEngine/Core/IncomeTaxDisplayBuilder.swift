//
//  IncomeTaxDisplayBuilder.swift
//  BuxMuse
//
//  Phase J — MSE-style income tax calculator display from WorldTaxEngine.
//

import Foundation

public struct IncomeTaxLineDisplay: Equatable, Identifiable {
    public var id: String
    public var labelKey: String
    public var formattedValue: String
    public var isRateLine: Bool

    public init(id: String, labelKey: String, formattedValue: String, isRateLine: Bool = false) {
        self.id = id
        self.labelKey = labelKey
        self.formattedValue = formattedValue
        self.isRateLine = isRateLine
    }
}

public enum IncomeTaxDisplayBuilder {

    public static func build(
        profile: StudioProfile,
        taxProfile: StudioTaxProfile,
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        mileageEntries: [MileageEntry],
        mileageRatePerUnit: Decimal,
        format: (Decimal) -> String,
        locale: Locale,
        now: Date = Date()
    ) -> IncomeTaxDisplay {
        let countryCode = taxProfile.selectedTaxCountry ?? profile.countryCode
        let period = WorldTaxEngine.defaultHubPeriod(countryCode: countryCode, reference: now)
        let incomePath: TaxEngineIncomePath = switch taxProfile.taxIncomeType {
        case .employed: .employedHypothetical
        case .oneOff: .gig
        case .selfEmployed: .selfEmployed
        }

        let request = TaxComputationRequest(
            profile: profile,
            taxProfile: taxProfile,
            invoices: invoices,
            receipts: receipts,
            mileageEntries: mileageEntries,
            mileageRatePerUnit: mileageRatePerUnit,
            incomePath: incomePath,
            period: period,
            locale: locale,
            now: now
        )

        let result = WorldTaxEngine.compute(request)
        let breakdown = result.legacyBreakdown
        let (periodStart, periodEnd) = WorldTaxEngine.periodBounds(for: request)

        let ratesConfigured = taxProfile.estimatedIncomeTaxRatePercent != nil
            || taxProfile.estimatedSelfEmployedRatePercent != nil
            || !taxProfile.incomeTaxRules.isEmpty
            || result.source != .legacyManualRates

        let detailLines = buildDetailLines(from: result.lines, format: format)
        let marginalRatePercent = result.lines
            .first(where: { $0.kind == .marginalRate })?
            .rate
            .map { Int(Double(truncating: ($0 * 100) as NSDecimalNumber)) }

        return IncomeTaxDisplay(
            totalIncomeFormatted: format(breakdown.totalIncome),
            deductibleExpensesFormatted: format(breakdown.deductibleExpenses),
            taxableIncomeFormatted: format(breakdown.taxableIncome),
            incomeTaxFormatted: format(breakdown.incomeTax),
            selfEmployedTaxFormatted: format(breakdown.selfEmployedTax),
            indirectTaxNetFormatted: format(breakdown.indirectTaxNet),
            totalEstimatedTaxFormatted: format(breakdown.totalEstimatedTax + breakdown.indirectTaxNet),
            effectiveRatePercent: Int(breakdown.effectiveRate * 100),
            ratesConfigured: ratesConfigured,
            netAfterTaxFormatted: format(result.netAfterTax),
            marginalRatePercent: marginalRatePercent,
            periodLabel: periodLabel(
                period: period,
                start: periodStart,
                end: periodEnd,
                locale: locale
            ),
            coverageTierLabel: result.coverageTier.catalogLabelKey,
            rulesAsOfLabel: rulesAsOfLabel(result: result, locale: locale),
            detailLines: detailLines,
            usesCatalogEngine: result.source != .legacyManualRates
        )
    }

    private static func buildDetailLines(
        from lines: [TaxComputationLine],
        format: (Decimal) -> String
    ) -> [IncomeTaxLineDisplay] {
        lines.compactMap { line in
            if let amount = line.amount {
                return IncomeTaxLineDisplay(
                    id: line.id,
                    labelKey: line.labelKey,
                    formattedValue: format(amount),
                    isRateLine: false
                )
            }
            if let rate = line.rate {
                let pct = Int(Double(truncating: (rate * 100) as NSDecimalNumber))
                return IncomeTaxLineDisplay(
                    id: line.id,
                    labelKey: line.labelKey,
                    formattedValue: "\(pct)%",
                    isRateLine: true
                )
            }
            return nil
        }
    }

    private static func periodLabel(
        period: TaxComputationPeriod,
        start: Date?,
        end: Date?,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium

        switch period {
        case .allTime:
            return BuxCatalogLabel.string("All recorded transactions", locale: locale)
        case .fiscalYearToDate:
            if let start, let end {
                return BuxLocalizedString.format(
                    "Fiscal year to date: %@ – %@",
                    locale: locale,
                    formatter.string(from: start),
                    formatter.string(from: end)
                )
            }
            return BuxCatalogLabel.string("Fiscal year to date", locale: locale)
        case .calendarQuarter, .fiscalQuarter:
            if let start, let end {
                return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
            }
            return BuxCatalogLabel.string("Current quarter", locale: locale)
        case .custom(let start, let end):
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        case .hypotheticalAnnual:
            return BuxCatalogLabel.string("Hypothetical annual", locale: locale)
        }
    }

    private static func rulesAsOfLabel(result: TaxComputationResult, locale: Locale) -> String? {
        if let updatedAt = result.catalogUpdatedAt, !updatedAt.isEmpty {
            let display = formatCatalogTimestamp(updatedAt, locale: locale) ?? updatedAt
            return BuxLocalizedString.format("Rules as of %@", locale: locale, display)
        }
        if let taxYear = result.taxYear, !taxYear.isEmpty {
            return BuxLocalizedString.format("Tax year %@", locale: locale, taxYear)
        }
        return nil
    }

    private static func formatCatalogTimestamp(_ raw: String, locale: Locale) -> String? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: raw)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: raw)
        }
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
