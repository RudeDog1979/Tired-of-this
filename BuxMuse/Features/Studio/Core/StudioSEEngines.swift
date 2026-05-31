//
//  StudioSEEngines.swift
//  BuxMuse
//
//  Self-employed OS engines: deductions math, income tax, quarterly, compliance.
//

import Foundation

// MARK: - Expense categories

public enum BusinessExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case materials = "Materials"
    case tools = "Tools"
    case software = "Software"
    case fuel = "Fuel"
    case homeOffice = "Home Office"
    case subcontractors = "Subcontractors"
    case meals = "Meals"
    case travel = "Travel"
    case education = "Education"
    case phoneInternet = "Phone & Internet"
    case equipment = "Equipment"
    case marketing = "Marketing"
    case insurance = "Insurance"
    case bankFees = "Bank Fees"
    case misc = "Misc"

    public var id: String { rawValue }

    public var defaultDeductible: Bool {
        switch self {
        case .meals, .travel: return true
        default: return true
        }
    }

    public var defaultStrength: DeductionStrength {
        switch self {
        case .meals, .travel: return .risky
        case .homeOffice, .phoneInternet: return .medium
        default: return .strong
        }
    }

    public var suggestedPartialPercent: Double? {
        switch self {
        case .meals: return 50
        case .homeOffice, .phoneInternet, .fuel: return 50
        default: return nil
        }
    }
}

public enum ExpenseBusinessUse: String, Codable, CaseIterable, Identifiable {
    case business = "Business"
    case personal = "Personal"
    case mixed = "Mixed"

    public var id: String { rawValue }
}

// MARK: - Deduction math

public enum StudioDeductionMath {
    public static func deductibleAmount(for receipt: StudioReceipt) -> Decimal {
        guard receipt.isBusiness, receipt.isDeductible else { return 0 }
        let pct = Decimal(receipt.deductiblePercentage / 100.0)
        return receipt.amount * pct
    }

    public static func totalDeductible(receipts: [StudioReceipt]) -> Decimal {
        receipts.reduce(Decimal(0)) { $0 + deductibleAmount(for: $1) }
    }

    public static func totalDeductible(
        receipts: [StudioReceipt],
        mileageEntries: [MileageEntry],
        mileageRatePerUnit: Decimal
    ) -> Decimal {
        totalDeductible(receipts: receipts) + MileageBrain.deductionAmount(entries: mileageEntries, ratePerUnit: mileageRatePerUnit)
    }

    public static func totalCashflowExpenses(receipts: [StudioReceipt]) -> Decimal {
        receipts.reduce(Decimal(0)) { $0 + $1.amount }
    }

    public static func categoryHint(for category: String, countryCode: String) -> (strength: DeductionStrength, note: String) {
        let lower = category.lowercased()
        if lower.contains("meal") || lower.contains("restaurant") {
            return (.risky, "Meals are often partially deductible — verify local rules for \(countryCode).")
        }
        if lower.contains("travel") || lower.contains("lodging") {
            return (.medium, "Travel deductions vary — keep receipts and business purpose notes.")
        }
        if lower.contains("home") || lower.contains("office") {
            return (.medium, "Home office often allows partial deduction for mixed-use space.")
        }
        if lower.contains("software") || lower.contains("cloud") {
            return (.strong, "Software used for work is typically fully deductible.")
        }
        return (.strong, "Standard business expense — confirm against your tax profile rules.")
    }
}

// MARK: - Income tax calculator

public struct IncomeTaxBreakdown: Equatable {
    public var totalIncome: Decimal
    public var deductibleExpenses: Decimal
    public var taxableIncome: Decimal
    public var incomeTax: Decimal
    public var selfEmployedTax: Decimal
    public var indirectTaxNet: Decimal
    public var totalEstimatedTax: Decimal
    public var effectiveRate: Double
}

public enum StudioIncomeTaxEngine {
    public static func compute(
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        taxProfile: StudioTaxProfile,
        mileageEntries: [MileageEntry] = [],
        mileageRatePerUnit: Decimal = 0,
        periodStart: Date? = nil,
        periodEnd: Date? = nil
    ) -> IncomeTaxBreakdown {
        let activeInvoices = filteredInvoices(invoices, start: periodStart, end: periodEnd)
        let filteredReceipts = filteredReceipts(receipts, start: periodStart, end: periodEnd)
        let filteredMileage = filteredMileage(mileageEntries, start: periodStart, end: periodEnd)

        let income = activeInvoices.reduce(Decimal(0)) { $0 + $1.subtotal }
        let deductions = StudioDeductionMath.totalDeductible(
            receipts: filteredReceipts,
            mileageEntries: filteredMileage,
            mileageRatePerUnit: mileageRatePerUnit
        )
        let taxable = max(0, income - deductions)

        let incomeRate = (taxProfile.estimatedIncomeTaxRatePercent ?? 0) / 100
        let seRate = (taxProfile.estimatedSelfEmployedRatePercent ?? 0) / 100

        let incomeTax = taxable * incomeRate
        let seTax = taxable * seRate

        var indirectNet: Decimal = 0
        if taxProfile.vatRegistered {
            let invoiceTax = activeInvoices.reduce(Decimal(0)) { $0 + $1.taxAmount }
            let expenseTax = filteredReceipts.reduce(Decimal(0)) { $0 + ($1.vatAmount ?? 0) }
            indirectNet = max(0, invoiceTax - expenseTax)
        }

        let totalTax = incomeTax + seTax
        let effective = income > 0 ? Double(truncating: (totalTax / income) as NSDecimalNumber) : 0

        return IncomeTaxBreakdown(
            totalIncome: income,
            deductibleExpenses: deductions,
            taxableIncome: taxable,
            incomeTax: incomeTax,
            selfEmployedTax: seTax,
            indirectTaxNet: indirectNet,
            totalEstimatedTax: totalTax,
            effectiveRate: effective
        )
    }

    private static func filteredInvoices(_ invoices: [StudioInvoice], start: Date?, end: Date?) -> [StudioInvoice] {
        invoices.filter { inv in
            guard inv.status == .paid || inv.status == .sent || inv.status == .overdue else { return false }
            if let start, inv.issueDate < start { return false }
            if let end, inv.issueDate > end { return false }
            return true
        }
    }

    private static func filteredReceipts(_ receipts: [StudioReceipt], start: Date?, end: Date?) -> [StudioReceipt] {
        receipts.filter { r in
            if let start, r.date < start { return false }
            if let end, r.date > end { return false }
            return true
        }
    }

    private static func filteredMileage(_ entries: [MileageEntry], start: Date?, end: Date?) -> [MileageEntry] {
        entries.filter { e in
            if let start, e.date < start { return false }
            if let end, e.date > end { return false }
            return true
        }
    }
}

// MARK: - Quarterly tax engine

public struct QuarterlyTaxEstimate: Equatable {
    public var quarterLabel: String
    public var periodStart: Date
    public var periodEnd: Date
    public var incomeTax: Decimal
    public var selfEmployedTax: Decimal
    public var indirectTaxCollected: Decimal
    public var totalDue: Decimal
    public var nextPaymentDate: Date?
    public var suggestedSetAside: Decimal
    public var breakdown: IncomeTaxBreakdown
}

public enum QuarterlyTaxEngine {
    public static func currentQuarterEstimate(
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        taxProfile: StudioTaxProfile,
        mileageEntries: [MileageEntry] = [],
        mileageRatePerUnit: Decimal = 0,
        taxYearStartMonth: Int = 1,
        now: Date = Date()
    ) -> QuarterlyTaxEstimate {
        let calendar = Calendar.current
        let (start, end, label) = quarterBounds(now: now, calendar: calendar)
        let breakdown = StudioIncomeTaxEngine.compute(
            invoices: invoices,
            receipts: receipts,
            taxProfile: taxProfile,
            mileageEntries: mileageEntries,
            mileageRatePerUnit: mileageRatePerUnit,
            periodStart: start,
            periodEnd: end
        )

        let nextPayment = nextPaymentDate(schedule: taxProfile.paymentSchedule, now: now, calendar: calendar)
        let setAside = breakdown.totalEstimatedTax + breakdown.indirectTaxNet

        return QuarterlyTaxEstimate(
            quarterLabel: label,
            periodStart: start,
            periodEnd: end,
            incomeTax: breakdown.incomeTax,
            selfEmployedTax: breakdown.selfEmployedTax,
            indirectTaxCollected: breakdown.indirectTaxNet,
            totalDue: breakdown.totalEstimatedTax + breakdown.indirectTaxNet,
            nextPaymentDate: nextPayment,
            suggestedSetAside: setAside,
            breakdown: breakdown
        )
    }

    private static func quarterBounds(now: Date, calendar: Calendar) -> (Date, Date, String) {
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let q = ((month - 1) / 3) + 1
        let startMonth = (q - 1) * 3 + 1
        let startComps = DateComponents(year: year, month: startMonth, day: 1)
        let start = calendar.date(from: startComps) ?? now
        let endComps = DateComponents(year: year, month: startMonth + 3, day: 1)
        let end = calendar.date(from: endComps)?.addingTimeInterval(-1) ?? now
        return (start, end, "Q\(q) \(year)")
    }

    private static func nextPaymentDate(schedule: String, now: Date, calendar: Calendar) -> Date? {
        switch schedule.lowercased() {
        case "monthly":
            var comps = calendar.dateComponents([.year, .month], from: now)
            comps.month = (comps.month ?? 1) + 1
            comps.day = 15
            return calendar.date(from: comps)
        case "quarterly":
            let month = calendar.component(.month, from: now)
            let qEndMonth = ((month - 1) / 3 + 1) * 3
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = qEndMonth + 1
            comps.day = 15
            return calendar.date(from: comps)
        default:
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = 4
            comps.day = 15
            if let d = calendar.date(from: comps), d > now { return d }
            comps.year = (comps.year ?? 2026) + 1
            return calendar.date(from: comps)
        }
    }
}

// MARK: - Compliance assistant

public struct ComplianceMessage: Identifiable, Equatable {
    public var id: String
    public var question: String
    public var answer: String
    public var severity: String
}

public struct ComplianceAssistantResult: Equatable {
    public var warnings: [ComplianceMessage]
    public var faq: [ComplianceMessage]
}

public enum ComplianceAssistantEngine {
    public static func analyze(
        taxProfile: StudioTaxProfile,
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        quarterly: QuarterlyTaxEstimate,
        countryCode: String
    ) -> ComplianceAssistantResult {
        var warnings: [ComplianceMessage] = []
        let income = quarterly.breakdown.totalIncome
        let deductible = quarterly.breakdown.deductibleExpenses

        if !taxProfile.vatRegistered && income > 0 {
            let thresholdNote = vatThresholdHint(countryCode: countryCode)
            warnings.append(ComplianceMessage(
                id: "vat-threshold",
                question: "Do I need to register for indirect tax?",
                answer: thresholdNote,
                severity: "medium"
            ))
        }

        if income > 0 && deductible / income < 0.05 {
            warnings.append(ComplianceMessage(
                id: "low-deductions",
                question: "Why are deductions low?",
                answer: "You have very few deductible expenses relative to income. Log business receipts to reduce taxable income.",
                severity: "medium"
            ))
        }

        if quarterly.totalDue > income * Decimal(0.35) {
            warnings.append(ComplianceMessage(
                id: "high-tax",
                question: "Why is my tax so high this quarter?",
                answer: "Estimated tax is over 35% of quarterly income. Review your effective rate settings in Tax Profile or add deductions.",
                severity: "high"
            ))
        }

        let faq: [ComplianceMessage] = [
            ComplianceMessage(
                id: "faq-deductible",
                question: "Is this expense deductible?",
                answer: "Business expenses marked deductible with valid receipts reduce taxable income. Risky categories (meals, travel) may be partial.",
                severity: "info"
            ),
            ComplianceMessage(
                id: "faq-late",
                question: "What if I don't pay this quarter?",
                answer: "Missing payments can lead to penalties and interest. This is informational — check your country's rules in Tax Profile.",
                severity: "info"
            ),
            ComplianceMessage(
                id: "faq-bracket",
                question: "Could I hit a higher bracket?",
                answer: income > 0
                    ? "Rising income may push you into higher rates. Review \(taxProfile.primaryTaxRulesText.prefix(120))…"
                    : "Add paid invoices to model bracket changes.",
                severity: "info"
            )
        ]

        return ComplianceAssistantResult(warnings: warnings, faq: faq)
    }

    private static func vatThresholdHint(countryCode: String) -> String {
        switch countryCode.uppercased() {
        case "GB", "UK": return "UK VAT registration is commonly required around £90,000 turnover. You're not marked as registered yet."
        case "US": return "US sales tax nexus varies by state. You are not marked as collecting indirect tax on invoices."
        case "DE", "FR", "ES", "IT", "NL": return "EU VAT registration thresholds vary. Monitor turnover against local rules in your Tax Profile."
        default: return "Review indirect tax registration thresholds for \(countryCode) in your saved tax rules."
        }
    }
}

// MARK: - Invoice settings & templates

public enum InvoiceTemplate: String, Codable, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case professional = "Professional"
    case freelancer = "Freelancer"
    case agency = "Agency"
    case localTaxHeavy = "Local Tax Heavy"

    public var id: String { rawValue }
}

public enum InvoiceTaxBehavior: String, Codable, CaseIterable, Identifiable {
    case taxAdded = "Tax added on top"
    case taxIncluded = "Tax included in prices"
    case noTax = "No tax"

    public var id: String { rawValue }
}

public enum InvoiceLogoPosition: String, Codable, CaseIterable, Identifiable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case none = "No Logo"

    public var id: String { rawValue }
}

public struct StudioInvoiceSettings: Codable, Equatable {
    public var numberPrefix: String
    public var numberPattern: String
    public var defaultTemplate: InvoiceTemplate
    public var defaultTaxBehavior: InvoiceTaxBehavior
    public var logoPosition: InvoiceLogoPosition
    public var documentLabel: String
    public var showTaxID: Bool
    public var showBankDetails: Bool
    public var bankDetails: String
    public var showLegalFooter: Bool
    public var defaultTaxRatePercent: Decimal?
    /// Persisted designer template config. Loaded as default on every new invoice.
    public var defaultTemplateConfig: InvoiceTemplateConfig?
    /// Persisted designer payment config. Loaded as default on every new invoice.
    public var defaultPaymentConfig: InvoicePaymentConfig?
    /// When true, new invoices and defaults follow the primary business card brand.
    public var brandSyncFromPrimaryCard: Bool
    /// Last card design ID applied to invoice defaults.
    public var brandSyncSourceDesignID: UUID?
    /// `updatedAt` of the card when invoice defaults were last synced.
    public var brandSyncSourceUpdatedAt: Date?

    public init(
        numberPrefix: String = "INV",
        numberPattern: String = "{PREFIX}-{YEAR}-{SEQ}",
        defaultTemplate: InvoiceTemplate = .professional,
        defaultTaxBehavior: InvoiceTaxBehavior = .taxAdded,
        logoPosition: InvoiceLogoPosition = .topLeft,
        documentLabel: String = "Invoice",
        showTaxID: Bool = false,
        showBankDetails: Bool = true,
        bankDetails: String = "",
        showLegalFooter: Bool = true,
        defaultTaxRatePercent: Decimal? = nil,
        defaultTemplateConfig: InvoiceTemplateConfig? = nil,
        defaultPaymentConfig: InvoicePaymentConfig? = nil,
        brandSyncFromPrimaryCard: Bool = true,
        brandSyncSourceDesignID: UUID? = nil,
        brandSyncSourceUpdatedAt: Date? = nil
    ) {
        self.numberPrefix          = numberPrefix
        self.numberPattern         = numberPattern
        self.defaultTemplate       = defaultTemplate
        self.defaultTaxBehavior    = defaultTaxBehavior
        self.logoPosition          = logoPosition
        self.documentLabel         = documentLabel
        self.showTaxID             = showTaxID
        self.showBankDetails       = showBankDetails
        self.bankDetails           = bankDetails
        self.showLegalFooter       = showLegalFooter
        self.defaultTaxRatePercent = defaultTaxRatePercent
        self.defaultTemplateConfig = defaultTemplateConfig
        self.defaultPaymentConfig  = defaultPaymentConfig
        self.brandSyncFromPrimaryCard = brandSyncFromPrimaryCard
        self.brandSyncSourceDesignID = brandSyncSourceDesignID
        self.brandSyncSourceUpdatedAt = brandSyncSourceUpdatedAt
    }

    public func formatInvoiceNumber(sequence: Int, year: Int) -> String {
        numberPattern
            .replacingOccurrences(of: "{PREFIX}", with: numberPrefix)
            .replacingOccurrences(of: "{YEAR}", with: "\(year)")
            .replacingOccurrences(of: "{SEQ}", with: String(format: "%04d", sequence))
    }
}

extension StudioInvoiceSettings {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        numberPrefix = try c.decode(String.self, forKey: .numberPrefix)
        numberPattern = try c.decode(String.self, forKey: .numberPattern)
        defaultTemplate = try c.decode(InvoiceTemplate.self, forKey: .defaultTemplate)
        defaultTaxBehavior = try c.decode(InvoiceTaxBehavior.self, forKey: .defaultTaxBehavior)
        logoPosition = try c.decode(InvoiceLogoPosition.self, forKey: .logoPosition)
        documentLabel = try c.decode(String.self, forKey: .documentLabel)
        showTaxID = try c.decode(Bool.self, forKey: .showTaxID)
        showBankDetails = try c.decode(Bool.self, forKey: .showBankDetails)
        bankDetails = try c.decode(String.self, forKey: .bankDetails)
        showLegalFooter = try c.decodeIfPresent(Bool.self, forKey: .showLegalFooter) ?? true
        defaultTaxRatePercent = try c.decodeIfPresent(Decimal.self, forKey: .defaultTaxRatePercent)
        defaultTemplateConfig = try c.decodeIfPresent(InvoiceTemplateConfig.self, forKey: .defaultTemplateConfig)
        defaultPaymentConfig = try c.decodeIfPresent(InvoicePaymentConfig.self, forKey: .defaultPaymentConfig)
        brandSyncFromPrimaryCard = try c.decodeIfPresent(Bool.self, forKey: .brandSyncFromPrimaryCard) ?? true
        brandSyncSourceDesignID = try c.decodeIfPresent(UUID.self, forKey: .brandSyncSourceDesignID)
        brandSyncSourceUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .brandSyncSourceUpdatedAt)
    }
}

public enum StudioInvoiceMaintenance {
    public static func syncOverdueStatuses(invoices: [StudioInvoice], now: Date = Date()) -> [StudioInvoice] {
        invoices.map { inv in
            var copy = inv
            if copy.status == .sent && copy.dueDate < now {
                copy.status = .overdue
            }
            return copy
        }
    }
}
