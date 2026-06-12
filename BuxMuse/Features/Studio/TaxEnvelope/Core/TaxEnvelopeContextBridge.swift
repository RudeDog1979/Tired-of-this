//
//  TaxEnvelopeContextBridge.swift
//  BuxMuse
//
//  Merges Simple Studio entries with Pro books for catalog-backed tax computation.
//

import Foundation

public struct TaxEnvelopeSourceContext: Equatable, Sendable {
    public var profile: StudioProfile
    public var taxProfile: StudioTaxProfile
    public var proInvoices: [StudioInvoice]
    public var proReceipts: [StudioReceipt]
    public var mileageEntries: [MileageEntry]
    public var simpleEntries: [SimpleStudioEntry]
    public var envelope: TaxEnvelopeState
    public var mileageRatePerUnit: Decimal
    public var locale: Locale
    public var now: Date
    /// Settings → Region & currency; used when no explicit tax-country preset is saved.
    public var appRegionCountryCode: String?

    public init(
        profile: StudioProfile,
        taxProfile: StudioTaxProfile,
        proInvoices: [StudioInvoice],
        proReceipts: [StudioReceipt],
        mileageEntries: [MileageEntry] = [],
        simpleEntries: [SimpleStudioEntry] = [],
        envelope: TaxEnvelopeState = TaxEnvelopeState(),
        mileageRatePerUnit: Decimal = 0,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale,
        now: Date = Date(),
        appRegionCountryCode: String? = nil
    ) {
        self.profile = profile
        self.taxProfile = taxProfile
        self.proInvoices = proInvoices
        self.proReceipts = proReceipts
        self.mileageEntries = mileageEntries
        self.simpleEntries = simpleEntries
        self.envelope = envelope
        self.mileageRatePerUnit = mileageRatePerUnit
        self.locale = locale
        self.now = now
        self.appRegionCountryCode = appRegionCountryCode
    }

    public var countryCode: String {
        if let preset = taxProfile.selectedTaxCountry, !preset.isEmpty {
            return TaxManager.normalizeCountryCode(preset)
        }
        if let appRegionCountryCode, !appRegionCountryCode.isEmpty {
            return TaxManager.normalizeCountryCode(appRegionCountryCode)
        }
        let saved = taxProfile.countryCode.isEmpty ? profile.countryCode : taxProfile.countryCode
        return TaxManager.normalizeCountryCode(saved)
    }
}

public enum TaxEnvelopeContextBridge {

    private static let syntheticClientId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public static func computationRequest(
        from context: TaxEnvelopeSourceContext,
        period: TaxComputationPeriod
    ) -> TaxComputationRequest {
        let incomePath: TaxEngineIncomePath = switch context.taxProfile.taxIncomeType {
        case .employed: .employedHypothetical
        case .oneOff: .gig
        case .selfEmployed: .selfEmployed
        }
        let (start, end) = WorldTaxEngine.periodBounds(for: TaxComputationRequest(
            profile: context.profile,
            taxProfile: context.taxProfile,
            invoices: [],
            receipts: [],
            period: period,
            now: context.now
        ))
        return TaxComputationRequest(
            profile: context.profile,
            taxProfile: context.taxProfile,
            invoices: mergedInvoices(
                pro: context.proInvoices,
                simpleEntries: context.simpleEntries,
                periodStart: start,
                periodEnd: end
            ),
            receipts: mergedReceipts(
                pro: context.proReceipts,
                simpleEntries: context.simpleEntries,
                periodStart: start,
                periodEnd: end
            ),
            mileageEntries: context.mileageEntries,
            mileageRatePerUnit: context.mileageRatePerUnit,
            incomePath: incomePath,
            period: period,
            locale: context.locale,
            now: context.now
        )
    }

    public static func mergedInvoices(
        pro: [StudioInvoice],
        simpleEntries: [SimpleStudioEntry],
        periodStart: Date?,
        periodEnd: Date?
    ) -> [StudioInvoice] {
        var result = pro
        for entry in simpleEntries {
            let gross = incomeAmount(for: entry)
            guard gross > 0 else { continue }
            guard inPeriod(entry.createdAt, start: periodStart, end: periodEnd) else { continue }
            result.append(syntheticInvoice(amount: gross, date: entry.createdAt, tag: entry.id))
        }
        return result
    }

    public static func mergedReceipts(
        pro: [StudioReceipt],
        simpleEntries: [SimpleStudioEntry],
        periodStart: Date?,
        periodEnd: Date?
    ) -> [StudioReceipt] {
        var result = pro
        for entry in simpleEntries {
            let deductions = deductibleAmount(for: entry)
            guard deductions > 0 else { continue }
            guard inPeriod(entry.createdAt, start: periodStart, end: periodEnd) else { continue }
            result.append(syntheticReceipt(amount: deductions, date: entry.createdAt, tag: entry.id))
        }
        return result
    }

    // MARK: - Simple entry math

    public static func incomeAmount(for entry: SimpleStudioEntry) -> Decimal {
        switch entry.kind {
        case .income, .job, .repaymentReceived:
            return entry.amount + (entry.tip ?? 0)
        case .owedToMe where entry.paymentStatus == .paid:
            return entry.amount
        default:
            return 0
        }
    }

    public static func deductibleAmount(for entry: SimpleStudioEntry) -> Decimal {
        switch entry.kind {
        case .expense, .iOwe, .lent:
            return entry.amount
        case .job, .income:
            return entry.jobCosts
        default:
            return 0
        }
    }

    public static func weekIncomeTotal(
        entries: [SimpleStudioEntry],
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Decimal {
        entries
            .filter { calendar.isDate($0.createdAt, equalTo: reference, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + incomeAmount(for: $1) }
    }

    // MARK: - Private

    private static func inPeriod(_ date: Date, start: Date?, end: Date?) -> Bool {
        if let start, date < start { return false }
        if let end, date > end { return false }
        return true
    }

    private static func syntheticInvoice(amount: Decimal, date: Date, tag: UUID) -> StudioInvoice {
        StudioInvoice(
            id: tag,
            clientId: syntheticClientId,
            invoiceNumber: "ENV-\(tag.uuidString.prefix(8))",
            issueDate: date,
            dueDate: date,
            status: .paid,
            subtotal: amount,
            taxAmount: 0,
            total: amount,
            notes: "TaxEnvelope synthetic"
        )
    }

    private static func syntheticReceipt(amount: Decimal, date: Date, tag: UUID) -> StudioReceipt {
        StudioReceipt(
            id: tag,
            date: date,
            amount: amount,
            merchant: "Simple Studio",
            category: "Business Expenses",
            isDeductible: true,
            notes: "TaxEnvelope synthetic"
        )
    }
}
