//
//  FreelanceModels.swift
//  BuxMuse
//
//  Premium self-employed & freelance CRM/billing models — strictly local & codable.
//

import Foundation

// MARK: - Core Enums

public enum BusinessType: String, Codable, CaseIterable, Identifiable {
    case soleTrader = "Sole Trader"
    case llc = "LLC"
    case selfEmployed = "Self Employed"
    case contractor = "Contractor"
    case freelancer = "Freelancer"
    
    public var id: String { rawValue }
}

public enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"
    
    public var id: String { rawValue }
}

public enum DeductionStrength: String, Codable, CaseIterable, Identifiable {
    case strong = "Strong"
    case medium = "Medium"
    case weak = "Weak"
    case risky = "Risky"
    
    public var id: String { rawValue }
}

/// How the user primarily earns income — drives which saved tax rules are shown in summaries.
public enum TaxIncomeType: String, Codable, CaseIterable, Identifiable {
    case selfEmployed = "Self-employed"
    case employed = "Employed"
    case oneOff = "One-off / gig"

    public var id: String { rawValue }

    public var summaryLabel: String {
        switch self {
        case .selfEmployed: return "Self-employed tax rules"
        case .employed: return "Employment tax rules"
        case .oneOff: return "One-off / gig guidance"
        }
    }
}

// MARK: - Freelance Profile

public struct FreelanceProfile: Codable, Equatable {
    public var id: UUID
    public var displayName: String
    public var businessName: String
    public var countryCode: String
    public var regionCode: String?
    public var currencyCode: String
    public var businessType: BusinessType
    public var vatRegistered: Bool
    public var taxYearStartMonth: Int // 1-12
    public var logoData: Data?
    public var defaultInvoicePaymentTerms: Int // e.g. 14, 30 days
    public var defaultHourlyRate: Decimal?
    public var defaultTaxProfileId: UUID?
    
    public init(
        id: UUID = UUID(),
        displayName: String = "",
        businessName: String = "",
        countryCode: String = "US",
        regionCode: String? = nil,
        currencyCode: String = "USD",
        businessType: BusinessType = .freelancer,
        vatRegistered: Bool = false,
        taxYearStartMonth: Int = 1,
        logoData: Data? = nil,
        defaultInvoicePaymentTerms: Int = 30,
        defaultHourlyRate: Decimal? = nil,
        defaultTaxProfileId: UUID? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.businessName = businessName
        self.countryCode = countryCode
        self.regionCode = regionCode
        self.currencyCode = currencyCode
        self.businessType = businessType
        self.vatRegistered = vatRegistered
        self.taxYearStartMonth = taxYearStartMonth
        self.logoData = logoData
        self.defaultInvoicePaymentTerms = defaultInvoicePaymentTerms
        self.defaultHourlyRate = defaultHourlyRate
        self.defaultTaxProfileId = defaultTaxProfileId
    }
}

// MARK: - Clients

public struct FreelanceClient: Codable, Identifiable, Hashable, Equatable {
    public var id: UUID
    public var name: String
    public var email: String
    public var phone: String
    public var address: String
    public var notes: String
    public var tags: [String]
    public var defaultRate: Decimal?
    public var paymentTermsDays: Int?
    public var isFlaggedForStress: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        phone: String = "",
        address: String = "",
        notes: String = "",
        tags: [String] = [],
        defaultRate: Decimal? = nil,
        paymentTermsDays: Int? = nil,
        isFlaggedForStress: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.address = address
        self.notes = notes
        self.tags = tags
        self.defaultRate = defaultRate
        self.paymentTermsDays = paymentTermsDays
        self.isFlaggedForStress = isFlaggedForStress
    }
}

// MARK: - Invoices

public struct FreelanceInvoiceLineItem: Codable, Identifiable, Hashable, Equatable {
    public var id: UUID
    public var description: String
    public var quantity: Double
    public var unitPrice: Decimal
    public var isTaxable: Bool
    public var category: String?
    
    public var total: Decimal {
        Decimal(quantity) * unitPrice
    }
    
    public init(
        id: UUID = UUID(),
        description: String,
        quantity: Double = 1.0,
        unitPrice: Decimal = 0.0,
        isTaxable: Bool = true,
        category: String? = nil
    ) {
        self.id = id
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.isTaxable = isTaxable
        self.category = category
    }
}

public struct FreelanceInvoice: Codable, Identifiable, Equatable {
    public var id: UUID
    public var clientId: UUID
    public var invoiceNumber: String
    public var issueDate: Date
    public var dueDate: Date
    public var status: InvoiceStatus
    public var currencyCode: String
    public var lineItems: [FreelanceInvoiceLineItem]
    public var subtotal: Decimal
    public var taxAmount: Decimal
    public var total: Decimal
    public var vatRate: Decimal? // In percentage, e.g. 20.0
    public var taxLabel: String
    public var notes: String
    public var paymentDate: Date?
    public var externalReference: String?
    public var projectId: UUID?
    
    public init(
        id: UUID = UUID(),
        clientId: UUID,
        invoiceNumber: String = "",
        issueDate: Date = Date(),
        dueDate: Date = Date().addingTimeInterval(30 * 24 * 3600),
        status: InvoiceStatus = .draft,
        currencyCode: String = "USD",
        lineItems: [FreelanceInvoiceLineItem] = [],
        subtotal: Decimal = 0,
        taxAmount: Decimal = 0,
        total: Decimal = 0,
        vatRate: Decimal? = nil,
        taxLabel: String = "Tax",
        notes: String = "",
        paymentDate: Date? = nil,
        externalReference: String? = nil,
        projectId: UUID? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.status = status
        self.currencyCode = currencyCode
        self.lineItems = lineItems
        self.subtotal = subtotal
        self.taxAmount = taxAmount
        self.total = total
        self.vatRate = vatRate
        self.taxLabel = taxLabel
        self.notes = notes
        self.paymentDate = paymentDate
        self.externalReference = externalReference
        self.projectId = projectId
    }

    private enum CodingKeys: String, CodingKey {
        case id, clientId, invoiceNumber, issueDate, dueDate, status, currencyCode
        case lineItems, subtotal, taxAmount, total, vatRate, taxLabel, notes
        case paymentDate, externalReference, projectId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clientId = try c.decode(UUID.self, forKey: .clientId)
        invoiceNumber = try c.decode(String.self, forKey: .invoiceNumber)
        issueDate = try c.decode(Date.self, forKey: .issueDate)
        dueDate = try c.decode(Date.self, forKey: .dueDate)
        status = try c.decode(InvoiceStatus.self, forKey: .status)
        currencyCode = try c.decode(String.self, forKey: .currencyCode)
        lineItems = try c.decode([FreelanceInvoiceLineItem].self, forKey: .lineItems)
        subtotal = try c.decode(Decimal.self, forKey: .subtotal)
        taxAmount = try c.decode(Decimal.self, forKey: .taxAmount)
        total = try c.decode(Decimal.self, forKey: .total)
        vatRate = try c.decodeIfPresent(Decimal.self, forKey: .vatRate)
        taxLabel = try c.decodeIfPresent(String.self, forKey: .taxLabel) ?? "Tax"
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        paymentDate = try c.decodeIfPresent(Date.self, forKey: .paymentDate)
        externalReference = try c.decodeIfPresent(String.self, forKey: .externalReference)
        projectId = try c.decodeIfPresent(UUID.self, forKey: .projectId)
    }
}

// MARK: - Projects & Time Tracking

public struct FreelanceTimeEntry: Codable, Identifiable, Hashable, Equatable {
    public var id: UUID
    public var projectId: UUID
    public var startTime: Date
    public var endTime: Date
    public var notes: String
    public var isBillable: Bool
    
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    public init(
        id: UUID = UUID(),
        projectId: UUID,
        startTime: Date = Date(),
        endTime: Date = Date(),
        notes: String = "",
        isBillable: Bool = true
    ) {
        self.id = id
        self.projectId = projectId
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.isBillable = isBillable
    }
}

public struct FreelanceProject: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var clientId: UUID?
    public var startDate: Date
    public var endDate: Date?
    public var hourlyRate: Decimal?
    public var fixedFee: Decimal?
    public var notes: String
    public var timeEntries: [FreelanceTimeEntry]
    public var expenseIds: [UUID] // Linked receipt IDs
    public var generatedInvoiceIds: [UUID]
    
    public init(
        id: UUID = UUID(),
        name: String,
        clientId: UUID? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        hourlyRate: Decimal? = nil,
        fixedFee: Decimal? = nil,
        notes: String = "",
        timeEntries: [FreelanceTimeEntry] = [],
        expenseIds: [UUID] = [],
        generatedInvoiceIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.clientId = clientId
        self.startDate = startDate
        self.endDate = endDate
        self.hourlyRate = hourlyRate
        self.fixedFee = fixedFee
        self.notes = notes
        self.timeEntries = timeEntries
        self.expenseIds = expenseIds
        self.generatedInvoiceIds = generatedInvoiceIds
    }
}

// MARK: - Receipts & Scans

public struct FreelanceReceipt: Codable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var amount: Decimal
    public var currencyCode: String
    public var merchant: String
    public var category: String
    public var vatAmount: Decimal?
    public var vatRate: Decimal?
    public var isDeductible: Bool
    public var deductionStrength: DeductionStrength
    public var linkedClientId: UUID?
    public var linkedProjectId: UUID?
    public var localImagePath: String? // Locally saved scan image path
    public var notes: String
    public var isBusiness: Bool
    public var deductiblePercentage: Double
    public var businessUse: ExpenseBusinessUse

    /// Deductible amount after percentage (computed helper).
    public var deductibleAmount: Decimal {
        FreelanceDeductionMath.deductibleAmount(for: self)
    }
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Decimal = 0,
        currencyCode: String = "USD",
        merchant: String = "",
        category: String = "Office Expenses",
        vatAmount: Decimal? = nil,
        vatRate: Decimal? = nil,
        isDeductible: Bool = true,
        deductionStrength: DeductionStrength = .strong,
        linkedClientId: UUID? = nil,
        linkedProjectId: UUID? = nil,
        localImagePath: String? = nil,
        notes: String = "",
        isBusiness: Bool = true,
        deductiblePercentage: Double = 100,
        businessUse: ExpenseBusinessUse = .business
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchant = merchant
        self.category = category
        self.vatAmount = vatAmount
        self.vatRate = vatRate
        self.isDeductible = isDeductible
        self.deductionStrength = deductionStrength
        self.linkedClientId = linkedClientId
        self.linkedProjectId = linkedProjectId
        self.localImagePath = localImagePath
        self.notes = notes
        self.isBusiness = isBusiness
        self.deductiblePercentage = deductiblePercentage
        self.businessUse = businessUse
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, amount, currencyCode, merchant, category, vatAmount, vatRate
        case isDeductible, deductionStrength, linkedClientId, linkedProjectId
        case localImagePath, notes, isBusiness, deductiblePercentage, businessUse
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        amount = try c.decode(Decimal.self, forKey: .amount)
        currencyCode = try c.decode(String.self, forKey: .currencyCode)
        merchant = try c.decode(String.self, forKey: .merchant)
        category = try c.decode(String.self, forKey: .category)
        vatAmount = try c.decodeIfPresent(Decimal.self, forKey: .vatAmount)
        vatRate = try c.decodeIfPresent(Decimal.self, forKey: .vatRate)
        isDeductible = try c.decodeIfPresent(Bool.self, forKey: .isDeductible) ?? true
        deductionStrength = try c.decodeIfPresent(DeductionStrength.self, forKey: .deductionStrength) ?? .strong
        linkedClientId = try c.decodeIfPresent(UUID.self, forKey: .linkedClientId)
        linkedProjectId = try c.decodeIfPresent(UUID.self, forKey: .linkedProjectId)
        localImagePath = try c.decodeIfPresent(String.self, forKey: .localImagePath)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isBusiness = try c.decodeIfPresent(Bool.self, forKey: .isBusiness) ?? true
        deductiblePercentage = try c.decodeIfPresent(Double.self, forKey: .deductiblePercentage) ?? 100
        businessUse = try c.decodeIfPresent(ExpenseBusinessUse.self, forKey: .businessUse) ?? .business
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(amount, forKey: .amount)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encode(merchant, forKey: .merchant)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(vatAmount, forKey: .vatAmount)
        try c.encodeIfPresent(vatRate, forKey: .vatRate)
        try c.encode(isDeductible, forKey: .isDeductible)
        try c.encode(deductionStrength, forKey: .deductionStrength)
        try c.encodeIfPresent(linkedClientId, forKey: .linkedClientId)
        try c.encodeIfPresent(linkedProjectId, forKey: .linkedProjectId)
        try c.encodeIfPresent(localImagePath, forKey: .localImagePath)
        try c.encode(notes, forKey: .notes)
        try c.encode(isBusiness, forKey: .isBusiness)
        try c.encode(deductiblePercentage, forKey: .deductiblePercentage)
        try c.encode(businessUse, forKey: .businessUse)
    }
}

// MARK: - Tax Configuration Primitives

public struct TaxBracketRule: Codable, Hashable, Equatable {
    public var lowerBound: Decimal
    public var upperBound: Decimal?
    public var rate: Decimal // e.g. 0.20 for 20%
    
    public init(lowerBound: Decimal, upperBound: Decimal? = nil, rate: Decimal) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.rate = rate
    }
}

public struct VatRule: Codable, Hashable, Equatable {
    public var rate: Decimal
    public var appliesToCategories: [String]?
    
    public init(rate: Decimal, appliesToCategories: [String]? = nil) {
        self.rate = rate
        self.appliesToCategories = appliesToCategories
    }
}

public enum DeductibilityType: String, Codable {
    case full = "Full (100%)"
    case partial = "Partial (50%)"
    case limited = "Limited / Flat Capped"
}

public struct DeductionCategoryRule: Codable, Identifiable, Hashable, Equatable {
    public var id: String { categoryId }
    public var categoryId: String
    public var name: String
    public var deductibilityType: DeductibilityType
    public var notes: String
    
    public init(categoryId: String, name: String, deductibilityType: DeductibilityType, notes: String = "") {
        self.categoryId = categoryId
        self.name = name
        self.deductibilityType = deductibilityType
        self.notes = notes
    }
}

public struct FreelanceTaxProfile: Codable, Identifiable, Equatable {
    public var id: UUID
    public var countryCode: String
    public var regionCode: String?
    public var businessType: BusinessType
    public var vatRegistered: Bool
    public var incomeTaxRules: [TaxBracketRule]
    public var vatRules: [VatRule]
    public var deductionCategories: [DeductionCategoryRule]
    public var paymentSchedule: String

    /// Optional JSON preset country (ISO code). Nil = fully custom profile.
    public var selectedTaxCountry: String?
    public var customIncomeTax: String?
    public var customSelfEmployedTax: String?
    public var customIndirectTax: String?
    public var customNotes: String?
    public var taxIncomeType: TaxIncomeType
    /// User-set effective rates for calculator (never auto-filled from JSON).
    public var estimatedIncomeTaxRatePercent: Decimal?
    public var estimatedSelfEmployedRatePercent: Decimal?

    public var effectiveIncomeTax: String { customIncomeTax ?? "" }
    public var effectiveSelfEmployedTax: String { customSelfEmployedTax ?? "" }
    public var effectiveIndirectTax: String { customIndirectTax ?? "" }
    public var effectiveNotes: String { customNotes ?? "" }

    /// Primary rule text for the selected income type (used in hub + sandbox summaries).
    public var primaryTaxRulesText: String {
        switch taxIncomeType {
        case .selfEmployed:
            if !effectiveSelfEmployedTax.isEmpty { return effectiveSelfEmployedTax }
            return effectiveIncomeTax
        case .employed:
            return effectiveIncomeTax
        case .oneOff:
            if !effectiveNotes.isEmpty { return effectiveNotes }
            return effectiveSelfEmployedTax
        }
    }

    public var isTaxProfileConfigured: Bool {
        !primaryTaxRulesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id, countryCode, regionCode, businessType, vatRegistered
        case incomeTaxRules, vatRules, deductionCategories, paymentSchedule
        case selectedTaxCountry, customIncomeTax, customSelfEmployedTax
        case customIndirectTax, customNotes, taxIncomeType
        case estimatedIncomeTaxRatePercent, estimatedSelfEmployedRatePercent
        case customVAT
    }

    public init(
        id: UUID = UUID(),
        countryCode: String = "US",
        regionCode: String? = nil,
        businessType: BusinessType = .freelancer,
        vatRegistered: Bool = false,
        incomeTaxRules: [TaxBracketRule] = [],
        vatRules: [VatRule] = [],
        deductionCategories: [DeductionCategoryRule] = [],
        paymentSchedule: String = "annually",
        selectedTaxCountry: String? = nil,
        customIncomeTax: String? = nil,
        customSelfEmployedTax: String? = nil,
        customIndirectTax: String? = nil,
        customNotes: String? = nil,
        taxIncomeType: TaxIncomeType = .selfEmployed,
        estimatedIncomeTaxRatePercent: Decimal? = nil,
        estimatedSelfEmployedRatePercent: Decimal? = nil
    ) {
        self.id = id
        self.countryCode = countryCode
        self.regionCode = regionCode
        self.businessType = businessType
        self.vatRegistered = vatRegistered
        self.incomeTaxRules = incomeTaxRules
        self.vatRules = vatRules
        self.deductionCategories = deductionCategories
        self.paymentSchedule = paymentSchedule
        self.selectedTaxCountry = selectedTaxCountry
        self.customIncomeTax = customIncomeTax
        self.customSelfEmployedTax = customSelfEmployedTax
        self.customIndirectTax = customIndirectTax
        self.customNotes = customNotes
        self.taxIncomeType = taxIncomeType
        self.estimatedIncomeTaxRatePercent = estimatedIncomeTaxRatePercent
        self.estimatedSelfEmployedRatePercent = estimatedSelfEmployedRatePercent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        regionCode = try container.decodeIfPresent(String.self, forKey: .regionCode)
        businessType = try container.decode(BusinessType.self, forKey: .businessType)
        vatRegistered = try container.decode(Bool.self, forKey: .vatRegistered)
        incomeTaxRules = try container.decode([TaxBracketRule].self, forKey: .incomeTaxRules)
        vatRules = try container.decode([VatRule].self, forKey: .vatRules)
        deductionCategories = try container.decode([DeductionCategoryRule].self, forKey: .deductionCategories)
        paymentSchedule = try container.decode(String.self, forKey: .paymentSchedule)
        selectedTaxCountry = try container.decodeIfPresent(String.self, forKey: .selectedTaxCountry)
        customIncomeTax = try container.decodeIfPresent(String.self, forKey: .customIncomeTax)
        customSelfEmployedTax = try container.decodeIfPresent(String.self, forKey: .customSelfEmployedTax)
        customIndirectTax = try container.decodeIfPresent(String.self, forKey: .customIndirectTax)
            ?? container.decodeIfPresent(String.self, forKey: .customVAT)
        customNotes = try container.decodeIfPresent(String.self, forKey: .customNotes)
        taxIncomeType = try container.decodeIfPresent(TaxIncomeType.self, forKey: .taxIncomeType) ?? .selfEmployed
        estimatedIncomeTaxRatePercent = try container.decodeIfPresent(Decimal.self, forKey: .estimatedIncomeTaxRatePercent)
        estimatedSelfEmployedRatePercent = try container.decodeIfPresent(Decimal.self, forKey: .estimatedSelfEmployedRatePercent)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(countryCode, forKey: .countryCode)
        try container.encodeIfPresent(regionCode, forKey: .regionCode)
        try container.encode(businessType, forKey: .businessType)
        try container.encode(vatRegistered, forKey: .vatRegistered)
        try container.encode(incomeTaxRules, forKey: .incomeTaxRules)
        try container.encode(vatRules, forKey: .vatRules)
        try container.encode(deductionCategories, forKey: .deductionCategories)
        try container.encode(paymentSchedule, forKey: .paymentSchedule)
        try container.encodeIfPresent(selectedTaxCountry, forKey: .selectedTaxCountry)
        try container.encodeIfPresent(customIncomeTax, forKey: .customIncomeTax)
        try container.encodeIfPresent(customSelfEmployedTax, forKey: .customSelfEmployedTax)
        try container.encodeIfPresent(customIndirectTax, forKey: .customIndirectTax)
        try container.encodeIfPresent(customNotes, forKey: .customNotes)
        try container.encode(taxIncomeType, forKey: .taxIncomeType)
        try container.encodeIfPresent(estimatedIncomeTaxRatePercent, forKey: .estimatedIncomeTaxRatePercent)
        try container.encodeIfPresent(estimatedSelfEmployedRatePercent, forKey: .estimatedSelfEmployedRatePercent)
    }
}

// MARK: - Snapshot (JSON persistence envelope)

public struct FreelanceSnapshot: Codable, Equatable {
    public var profile: FreelanceProfile
    public var clients: [FreelanceClient]
    public var invoices: [FreelanceInvoice]
    public var projects: [FreelanceProject]
    public var receipts: [FreelanceReceipt]
    public var taxProfile: FreelanceTaxProfile
    public var invoiceSettings: FreelanceInvoiceSettings

    public init(
        profile: FreelanceProfile,
        clients: [FreelanceClient],
        invoices: [FreelanceInvoice],
        projects: [FreelanceProject],
        receipts: [FreelanceReceipt],
        taxProfile: FreelanceTaxProfile,
        invoiceSettings: FreelanceInvoiceSettings = FreelanceInvoiceSettings()
    ) {
        self.profile = profile
        self.clients = clients
        self.invoices = invoices
        self.projects = projects
        self.receipts = receipts
        self.taxProfile = taxProfile
        self.invoiceSettings = invoiceSettings
    }

    private enum CodingKeys: String, CodingKey {
        case profile, clients, invoices, projects, receipts, taxProfile, invoiceSettings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(FreelanceProfile.self, forKey: .profile)
        clients = try c.decode([FreelanceClient].self, forKey: .clients)
        invoices = try c.decode([FreelanceInvoice].self, forKey: .invoices)
        projects = try c.decode([FreelanceProject].self, forKey: .projects)
        receipts = try c.decode([FreelanceReceipt].self, forKey: .receipts)
        taxProfile = try c.decode(FreelanceTaxProfile.self, forKey: .taxProfile)
        invoiceSettings = try c.decodeIfPresent(FreelanceInvoiceSettings.self, forKey: .invoiceSettings) ?? FreelanceInvoiceSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(profile, forKey: .profile)
        try c.encode(clients, forKey: .clients)
        try c.encode(invoices, forKey: .invoices)
        try c.encode(projects, forKey: .projects)
        try c.encode(receipts, forKey: .receipts)
        try c.encode(taxProfile, forKey: .taxProfile)
        try c.encode(invoiceSettings, forKey: .invoiceSettings)
    }
}
