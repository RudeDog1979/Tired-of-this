//
//  WorldTaxEngine.swift
//  BuxMuse
//
//  Tax Engine v2 router — additive; legacy flat-rate path preserved (Phase 0).
//

import Foundation

public enum WorldTaxEngine {

    /// Primary v2 entry. Falls back to existing `StudioIncomeTaxEngine` until country modules ship.
    public static func compute(_ request: TaxComputationRequest) -> TaxComputationResult {
        let countryCode = request.countryCode
        let (periodStart, periodEnd) = periodBounds(for: request)

        if let entry = TaxComputeCatalogStore.shared.entry(for: countryCode) {
            if entry.meta.coverageTier == .verified,
               let module = CountryTaxModuleRegistry.module(for: countryCode),
               let modular = module.compute(
                   request: request,
                   entry: entry,
                   periodStart: periodStart,
                   periodEnd: periodEnd
               ) {
                return modular
            }

            if catalogHasIncomeBrackets(entry),
               let generic = GenericTaxModule(isoCode: countryCode).compute(
                   request: request,
                   entry: entry,
                   periodStart: periodStart,
                   periodEnd: periodEnd
               ) {
                return generic
            }
        }

        return legacyResult(
            request: request,
            countryCode: countryCode,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
    }

    /// Hub / Studio default period — fiscal YTD for catalog-backed countries.
    public static func defaultHubPeriod(
        countryCode: String,
        reference: Date = Date()
    ) -> TaxComputationPeriod {
        guard let entry = TaxComputeCatalogStore.shared.entry(for: countryCode),
              entry.meta.coverageTier == .verified || entry.meta.coverageTier == .structured,
              catalogHasIncomeBrackets(entry) else {
            return .allTime
        }
        return .fiscalYearToDate(reference: reference)
    }

    /// Quarterly estimates use fiscal quarters when catalog metadata is available.
    public static func defaultQuarterPeriod(
        countryCode: String,
        reference: Date = Date()
    ) -> TaxComputationPeriod {
        guard TaxComputeCatalogStore.shared.entry(for: countryCode) != nil else {
            return .calendarQuarter(reference: reference)
        }
        return .fiscalQuarter(reference: reference)
    }

    public static func quarterLabel(
        countryCode: String,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let entry = TaxComputeCatalogStore.shared.entry(for: countryCode)
        let startMonth = entry?.meta.fiscalYearStartMonth ?? 1
        let startDay = entry?.meta.fiscalYearStartDay ?? 1
        let (_, _, label) = fiscalQuarterBounds(
            reference: reference,
            fiscalStartMonth: startMonth,
            fiscalStartDay: startDay,
            calendar: calendar
        )
        return label
    }

    public static func catalogHasIncomeBrackets(_ entry: TaxCountryComputeEntry) -> Bool {
        let block = entry.mergedBlock(forRegion: nil)
        return !(block.selfEmployed?.brackets.isEmpty ?? true)
    }

    public static func defaultHubPeriod(for context: TaxStudioContext) -> TaxComputationPeriod {
        let countryCode = context.taxProfile.selectedTaxCountry ?? context.profile.countryCode
        return defaultHubPeriod(countryCode: countryCode, reference: context.now)
    }

    /// Studio hub bridge — returns legacy breakdown shape for existing UI.
    public static func incomeTaxBreakdown(
        profile: StudioProfile,
        taxProfile: StudioTaxProfile,
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        mileageEntries: [MileageEntry] = [],
        mileageRatePerUnit: Decimal = 0,
        period: TaxComputationPeriod? = nil,
        now: Date = Date()
    ) -> IncomeTaxBreakdown {
        let countryCode = taxProfile.selectedTaxCountry ?? profile.countryCode
        let resolvedPeriod = period ?? defaultHubPeriod(countryCode: countryCode, reference: now)
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
            period: resolvedPeriod,
            now: now
        )
        return compute(request).legacyBreakdown
    }

    public static func compute(from context: TaxStudioContext, period: TaxComputationPeriod? = nil) -> TaxComputationResult {
        let incomePath: TaxEngineIncomePath
        switch context.taxProfile.taxIncomeType {
        case .employed: incomePath = .employedHypothetical
        case .oneOff: incomePath = .gig
        case .selfEmployed: incomePath = .selfEmployed
        }

        let resolvedPeriod = period ?? defaultHubPeriod(for: context)
        let request = TaxComputationRequest(
            profile: context.profile,
            taxProfile: context.taxProfile,
            invoices: context.invoices,
            receipts: context.receipts,
            mileageEntries: context.mileageEntries,
            mileageRatePerUnit: SettingsStore.shared.mileageRatePerUnit,
            incomePath: incomePath,
            period: resolvedPeriod,
            locale: context.locale,
            now: context.now
        )
        return compute(request)
    }

    // MARK: - Legacy bridge (unchanged math)

    private static func legacyResult(
        request: TaxComputationRequest,
        countryCode: String,
        periodStart: Date?,
        periodEnd: Date?
    ) -> TaxComputationResult {
        let breakdown = StudioIncomeTaxEngine.compute(
            invoices: request.invoices,
            receipts: request.receipts,
            taxProfile: request.taxProfile,
            mileageEntries: request.mileageEntries,
            mileageRatePerUnit: request.mileageRatePerUnit,
            periodStart: periodStart,
            periodEnd: periodEnd
        )

        let tier = TaxComputeCatalogStore.shared.coverageTier(for: countryCode)
        let catalog = TaxComputeCatalogStore.shared.payload
        let entry = catalog?.countries[countryCode]

        let lines: [TaxComputationLine] = [
            TaxComputationLine(id: "gross", kind: .grossIncome, amount: breakdown.totalIncome),
            TaxComputationLine(id: "deductions", kind: .deductibleExpenses, amount: breakdown.deductibleExpenses),
            TaxComputationLine(id: "taxable", kind: .taxableIncome, amount: breakdown.taxableIncome),
            TaxComputationLine(id: "income-tax", kind: .incomeTax, amount: breakdown.incomeTax),
            TaxComputationLine(id: "se-tax", kind: .selfEmployedTax, amount: breakdown.selfEmployedTax),
            TaxComputationLine(id: "indirect", kind: .indirectTax, amount: breakdown.indirectTaxNet),
            TaxComputationLine(
                id: "total",
                kind: .totalTax,
                amount: breakdown.totalEstimatedTax + breakdown.indirectTaxNet
            ),
            TaxComputationLine(
                id: "net",
                kind: .netAfterTax,
                amount: max(0, breakdown.totalIncome - breakdown.totalEstimatedTax - breakdown.indirectTaxNet)
            ),
            TaxComputationLine(
                id: "effective",
                kind: .effectiveRate,
                rate: Decimal(breakdown.effectiveRate)
            ),
        ]

        return TaxComputationResult(
            countryCode: countryCode,
            regionCode: request.regionCode,
            coverageTier: tier,
            source: .legacyManualRates,
            catalogUpdatedAt: catalog?.updatedAt,
            taxYear: entry?.meta.taxYear,
            lines: lines,
            legacyBreakdown: breakdown
        )
    }

    // MARK: - Period helpers

    public static func periodBounds(for request: TaxComputationRequest) -> (Date?, Date?) {
        let calendar = Calendar.current
        switch request.period {
        case .allTime:
            return (nil, nil)
        case .hypotheticalAnnual:
            return (nil, nil)
        case .custom(let start, let end):
            return (start, end)
        case .calendarQuarter(let reference):
            return calendarQuarterBounds(reference: reference, calendar: calendar)
        case .fiscalQuarter(let reference):
            let entry = TaxComputeCatalogStore.shared.entry(for: request.countryCode)
            let startMonth = entry?.meta.fiscalYearStartMonth ?? 1
            let startDay = entry?.meta.fiscalYearStartDay ?? 1
            let bounds = fiscalQuarterBounds(
                reference: reference,
                fiscalStartMonth: startMonth,
                fiscalStartDay: startDay,
                calendar: calendar
            )
            return (bounds.start, bounds.end)
        case .fiscalYearToDate(let reference):
            let entry = TaxComputeCatalogStore.shared.entry(for: request.countryCode)
            let startMonth = entry?.meta.fiscalYearStartMonth ?? 1
            let startDay = entry?.meta.fiscalYearStartDay ?? 1
            let start = fiscalYearStart(
                containing: reference,
                startMonth: startMonth,
                startDay: startDay,
                calendar: calendar
            )
            return (start, reference)
        }
    }

    private static func calendarQuarterBounds(reference: Date, calendar: Calendar) -> (Date, Date) {
        let (start, end, _) = calendarQuarterBoundsWithLabel(reference: reference, calendar: calendar)
        return (start, end)
    }

    private static func calendarQuarterBoundsWithLabel(
        reference: Date,
        calendar: Calendar
    ) -> (Date, Date, String) {
        let month = calendar.component(.month, from: reference)
        let year = calendar.component(.year, from: reference)
        let quarter = ((month - 1) / 3) + 1
        let startMonth = (quarter - 1) * 3 + 1
        let startComps = DateComponents(year: year, month: startMonth, day: 1)
        let start = calendar.date(from: startComps) ?? reference
        let endComps = DateComponents(year: year, month: startMonth + 3, day: 1)
        let end = calendar.date(from: endComps)?.addingTimeInterval(-1) ?? reference
        return (start, end, "Q\(quarter) \(year)")
    }

    static func fiscalQuarterBounds(
        reference: Date,
        fiscalStartMonth: Int,
        fiscalStartDay: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date, label: String) {
        if fiscalStartMonth == 1 && fiscalStartDay == 1 {
            let (start, end, label) = calendarQuarterBoundsWithLabel(reference: reference, calendar: calendar)
            return (start, end, label)
        }

        let fyStart = fiscalYearStart(
            containing: reference,
            startMonth: fiscalStartMonth,
            startDay: fiscalStartDay,
            calendar: calendar
        )
        let comps = calendar.dateComponents([.year, .month], from: fyStart, to: reference)
        let elapsedMonths = max(0, (comps.year ?? 0) * 12 + (comps.month ?? 0))
        let quarterIndex = min(3, elapsedMonths / 3)

        let quarterStart = calendar.date(byAdding: .month, value: quarterIndex * 3, to: fyStart) ?? fyStart
        let nextQuarterStart = calendar.date(byAdding: .month, value: (quarterIndex + 1) * 3, to: fyStart) ?? reference
        let quarterEnd = nextQuarterStart.addingTimeInterval(-1)

        let fyYear = calendar.component(.year, from: fyStart)
        return (quarterStart, quarterEnd, "FQ\(quarterIndex + 1) \(fyYear)")
    }

    private static func fiscalYearStart(
        containing date: Date,
        startMonth: Int,
        startDay: Int,
        calendar: Calendar
    ) -> Date {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        var fyYear = year
        if month < startMonth || (month == startMonth && day < startDay) {
            fyYear -= 1
        }
        let comps = DateComponents(year: fyYear, month: startMonth, day: startDay)
        return calendar.date(from: comps) ?? date
    }
}
