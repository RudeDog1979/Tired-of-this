//
//  DebtModels.swift
//  BuxMuse
//  Features/Debt/
//
//  Core data models for consumer debt tracking.
//

import Foundation

public enum DebtType: String, Codable, CaseIterable, Identifiable {
    case creditCard
    case personalLoan
    case student
    case mortgage
    case other

    public var id: String { rawValue }

    public var catalogLabelKey: String {
        switch self {
        case .creditCard: return "Credit card"
        case .personalLoan: return "Personal loan"
        case .student: return "Student loan"
        case .mortgage: return "Mortgage"
        case .other: return "Other debt"
        }
    }

    public var systemImage: String {
        switch self {
        case .creditCard: return "creditcard.fill"
        case .personalLoan: return "banknote.fill"
        case .student: return "graduationcap.fill"
        case .mortgage: return "house.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

public enum DebtLenderSource: String, Codable, CaseIterable, Identifiable {
    case bank
    case creditUnion
    case friendOrFamily
    case privateIndividual
    case informalLender
    case other

    public var id: String { rawValue }

    public var catalogLabelKey: String {
        switch self {
        case .bank: return "Bank"
        case .creditUnion: return "Credit union"
        case .friendOrFamily: return "Friend or family"
        case .privateIndividual: return "Private individual"
        case .informalLender: return "Informal lender"
        case .other: return "Other source"
        }
    }

    public var systemImage: String {
        switch self {
        case .bank: return "building.columns.fill"
        case .creditUnion: return "person.3.fill"
        case .friendOrFamily: return "heart.circle.fill"
        case .privateIndividual: return "person.circle.fill"
        case .informalLender: return "hand.raised.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    public var usesInstitutionLogo: Bool {
        self == .bank || self == .creditUnion
    }
}

public struct Debt: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var type: DebtType
    public var currentBalance: Decimal
    public var originalBalance: Decimal?
    public var aprPercent: Decimal?
    public var minimumPayment: Decimal?
    public var dueDayOfMonth: Int?
    public var lender: String?
    public var lenderSource: DebtLenderSource
    public var remindersEnabled: Bool
    public var notes: String?
    public var isArchived: Bool
    public var createdAt: Date
    public var payments: [DebtPayment]

    public init(
        id: UUID = UUID(),
        name: String,
        type: DebtType = .other,
        currentBalance: Decimal,
        originalBalance: Decimal? = nil,
        aprPercent: Decimal? = nil,
        minimumPayment: Decimal? = nil,
        dueDayOfMonth: Int? = nil,
        lender: String? = nil,
        lenderSource: DebtLenderSource = .bank,
        remindersEnabled: Bool = true,
        notes: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        payments: [DebtPayment] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.currentBalance = currentBalance
        self.originalBalance = originalBalance
        self.aprPercent = aprPercent
        self.minimumPayment = minimumPayment
        self.dueDayOfMonth = dueDayOfMonth
        self.lender = lender
        self.lenderSource = lenderSource
        self.remindersEnabled = remindersEnabled
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.payments = payments
    }

    /// First day of the calendar month when the debt is projected to be paid off,
    /// using APR and minimum payment when both are set.
    public var estimatedPayoffMonth: Date? {
        guard let apr = aprPercent, apr > 0,
              let minPayment = minimumPayment, minPayment > 0,
              currentBalance > 0 else { return nil }

        var balance = currentBalance
        let monthlyRate = apr / 100 / 12
        var months = 0
        let maxMonths = 600

        while balance > 0, months < maxMonths {
            let interest = balance * monthlyRate
            if minPayment <= interest { return nil }
            balance = balance + interest - minPayment
            months += 1
        }

        guard months > 0, months < maxMonths else { return nil }
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return calendar.date(byAdding: .month, value: months, to: startOfMonth)
    }

    public var paidThisMonth: Decimal {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return 0 }
        return payments
            .filter { interval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    public var nextDueDate: Date? {
        guard let day = dueDayOfMonth, (1...28).contains(day) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        guard var candidate = calendar.date(from: components) else { return nil }
        if candidate < now {
            candidate = calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    /// Best name for merchant/bank logo lookup — lender first, then account name.
    public var logoMerchantName: String {
        let trimmedLender = lender?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedLender.isEmpty { return trimmedLender }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var institutionLogoName: String? {
        let trimmed = lender?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    public var shouldFetchInstitutionLogo: Bool {
        guard lenderSource.usesInstitutionLogo, let name = institutionLogoName else { return false }
        return FinancialInstitutionCatalog.hasKnownInstitution(name)
    }

    public var paidDownFraction: Double? {
        guard let original = originalBalance, original > 0 else { return nil }
        let paid = max(0, original - currentBalance)
        return min(1, max(0, NSDecimalNumber(decimal: paid / original).doubleValue))
    }

    public var daysUntilDue: Int? {
        guard let due = nextDueDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: due)
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}

public struct DebtPayment: Identifiable, Codable, Equatable {
    public let id: UUID
    public let amount: Decimal
    public let date: Date
    public var notes: String?
    public var linkedExpenseId: UUID?

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date = Date(),
        notes: String? = nil,
        linkedExpenseId: UUID? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.notes = notes
        self.linkedExpenseId = linkedExpenseId
    }
}
