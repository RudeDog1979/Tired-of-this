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
        self.notes = notes
        self.paymentDate = paymentDate
        self.externalReference = externalReference
        self.projectId = projectId
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
        notes: String = ""
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

    public init(
        id: UUID = UUID(),
        countryCode: String = "US",
        regionCode: String? = nil,
        businessType: BusinessType = .freelancer,
        vatRegistered: Bool = false,
        incomeTaxRules: [TaxBracketRule] = [],
        vatRules: [VatRule] = [],
        deductionCategories: [DeductionCategoryRule] = [],
        paymentSchedule: String = "annually"
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

    public init(
        profile: FreelanceProfile,
        clients: [FreelanceClient],
        invoices: [FreelanceInvoice],
        projects: [FreelanceProject],
        receipts: [FreelanceReceipt],
        taxProfile: FreelanceTaxProfile
    ) {
        self.profile = profile
        self.clients = clients
        self.invoices = invoices
        self.projects = projects
        self.receipts = receipts
        self.taxProfile = taxProfile
    }
}
