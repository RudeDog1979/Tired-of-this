//
//  ExpenseModels.swift
//  BuxMuse
//
//  Expense domain models for SwiftData-backed expenses UI.
//

import Foundation

// MARK: - Record

struct ExpenseRecord: Identifiable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var amountValue: Decimal
    public var currencyCode: String
    public var categoryId: UUID?
    public var merchantId: UUID?
    public var date: Date
    public var notes: String?
    public var isRecurring: Bool
    public var recurrenceType: String?
    public var recurrenceConfidence: Double?
    public var nextExpectedDate: Date?
    public var isSubscriptionLike: Bool
    public var isTrial: Bool
    public var subscriptionStartDate: Date?
    public var trialEndDate: Date?
    public var renewalReminderDays: Int?
    public var heatZoneBucket: String?
    public var emotion: String?
    public var contextTag: String?
    public var habitSignatureId: String?
    public var subscriptionConfidence: Double?
    public var microCommitmentType: String?
    public var microCommitmentValue: Double?
    public var futureImpact1Y: Double?
    public var futureImpact5Y: Double?
    public var createdAt: Date
    public var updatedAt: Date
    public var categoryRaw: String
    public var merchantName: String

    public var amountDouble: Double {
        NSDecimalNumber(decimal: amountValue).doubleValue
    }

    public var transactionCategory: TransactionCategory {
        TransactionCategory(rawValue: categoryRaw) ?? .other
    }

    public var isRefund: Bool {
        amountValue > 0 && transactionCategory != .income
    }

    public init(
        id: UUID = UUID(),
        name: String,
        amountValue: Decimal,
        currencyCode: String,
        categoryId: UUID? = nil,
        merchantId: UUID? = nil,
        date: Date,
        notes: String? = nil,
        isRecurring: Bool = false,
        recurrenceType: String? = nil,
        recurrenceConfidence: Double? = nil,
        nextExpectedDate: Date? = nil,
        isSubscriptionLike: Bool = false,
        isTrial: Bool = false,
        subscriptionStartDate: Date? = nil,
        trialEndDate: Date? = nil,
        renewalReminderDays: Int? = nil,
        heatZoneBucket: String? = nil,
        emotion: String? = nil,
        contextTag: String? = nil,
        habitSignatureId: String? = nil,
        subscriptionConfidence: Double? = nil,
        microCommitmentType: String? = nil,
        microCommitmentValue: Double? = nil,
        futureImpact1Y: Double? = nil,
        futureImpact5Y: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        categoryRaw: String,
        merchantName: String
    ) {
        self.id = id
        self.name = name
        self.amountValue = amountValue
        self.currencyCode = currencyCode
        self.categoryId = categoryId
        self.merchantId = merchantId
        self.date = date
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
        self.recurrenceConfidence = recurrenceConfidence
        self.nextExpectedDate = nextExpectedDate
        self.isSubscriptionLike = isSubscriptionLike
        self.isTrial = isTrial
        self.subscriptionStartDate = subscriptionStartDate
        self.trialEndDate = trialEndDate
        self.renewalReminderDays = renewalReminderDays
        self.heatZoneBucket = heatZoneBucket
        self.emotion = emotion
        self.contextTag = contextTag
        self.habitSignatureId = habitSignatureId
        self.subscriptionConfidence = subscriptionConfidence
        self.microCommitmentType = microCommitmentType
        self.microCommitmentValue = microCommitmentValue
        self.futureImpact1Y = futureImpact1Y
        self.futureImpact5Y = futureImpact5Y
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.categoryRaw = categoryRaw
        self.merchantName = merchantName
    }

    public func toTransaction() -> Transaction {
        Transaction(
            id: id,
            date: date,
            amount: MoneyAmount(value: amountValue, currencyCode: currencyCode),
            merchantName: name,
            category: transactionCategory,
            notes: notes
        )
    }

    public static func from(_ entity: ExpenseEntity) -> ExpenseRecord {
        ExpenseRecord(
            id: entity.id,
            name: entity.name.isEmpty ? entity.merchantName : entity.name,
            amountValue: entity.amountValue,
            currencyCode: entity.currencyCode,
            categoryId: entity.categoryId,
            merchantId: entity.merchantId,
            date: entity.date,
            notes: entity.notes,
            isRecurring: entity.isRecurring,
            recurrenceType: entity.recurrenceType,
            recurrenceConfidence: entity.recurrenceConfidence,
            nextExpectedDate: entity.nextExpectedDate,
            isSubscriptionLike: entity.isSubscriptionLike,
            isTrial: entity.isTrial,
            subscriptionStartDate: entity.subscriptionStartDate,
            trialEndDate: entity.trialEndDate,
            renewalReminderDays: entity.renewalReminderDays,
            heatZoneBucket: entity.heatZoneBucket,
            emotion: entity.emotion,
            contextTag: entity.contextTag,
            habitSignatureId: entity.habitSignatureId,
            subscriptionConfidence: entity.subscriptionConfidence,
            microCommitmentType: entity.microCommitmentType,
            microCommitmentValue: entity.microCommitmentValue,
            futureImpact1Y: entity.futureImpact1Y,
            futureImpact5Y: entity.futureImpact5Y,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            categoryRaw: entity.categoryRaw,
            merchantName: entity.merchantName.isEmpty ? entity.name : entity.merchantName
        )
    }

    public static func from(_ transaction: Transaction, categoryId: UUID?, merchantId: UUID?) -> ExpenseRecord {
        ExpenseRecord(
            id: transaction.id,
            name: transaction.merchantName,
            amountValue: transaction.amount.value,
            currencyCode: transaction.amount.currencyCode,
            categoryId: categoryId,
            merchantId: merchantId,
            date: transaction.date,
            notes: transaction.notes,
            categoryRaw: transaction.category.rawValue,
            merchantName: transaction.merchantName
        )
    }
}

// MARK: - Category record

struct ExpenseCategoryRecord: Identifiable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var color: String
    public var isCustom: Bool
    public var isSubscriptionCategory: Bool
    public var subscriptionFrequency: String?
    public var systemCategoryRaw: String?

    public var transactionCategory: TransactionCategory? {
        guard let raw = systemCategoryRaw else { return nil }
        return TransactionCategory(rawValue: raw)
    }

    public static func from(_ entity: CategoryEntity) -> ExpenseCategoryRecord {
        ExpenseCategoryRecord(
            id: entity.id,
            name: entity.name,
            icon: entity.icon,
            color: entity.color,
            isCustom: entity.isCustom,
            isSubscriptionCategory: entity.isSubscriptionCategory,
            subscriptionFrequency: entity.subscriptionFrequency,
            systemCategoryRaw: entity.systemCategoryRaw
        )
    }
}

// MARK: - Merchant record

struct ExpenseMerchantRecord: Identifiable, Equatable, Hashable {
    public let id: UUID
    public var normalizedName: String
    public var name: String
    public var logoURL: String?
    public var localLogoPath: String?
    public var cluster: String?
    public var riskScore: Double?
    public var isSubscriptionMerchant: Bool

    public static func from(_ entity: MerchantEntity) -> ExpenseMerchantRecord {
        ExpenseMerchantRecord(
            id: entity.id,
            normalizedName: entity.normalizedName,
            name: entity.name,
            logoURL: entity.logoURL,
            localLogoPath: entity.localLogoPath,
            cluster: entity.cluster,
            riskScore: entity.riskScore,
            isSubscriptionMerchant: entity.isSubscriptionMerchant
        )
    }
}

// MARK: - Intelligence display

struct ExpenseIntelligenceDisplay: Equatable {
    public var recurrenceSummary: String?
    public var subscriptionSummary: String?
    public var heatZoneSummary: String?
    public var refundSummary: String?
    public var duplicateSummary: String?
    public var categoryInsight: String?
    public var merchantInsight: String?
    public var goalsImpact: String?
    public var subscriptionsImpact: String?
    public var habitSignatureSummary: String?
    public var futureImpactSummary: String?
    public var microCommitmentSummary: String?
    public var emotionalTagSummary: String?
    public var contextTagSummary: String?

    public static let empty = ExpenseIntelligenceDisplay()
}

// MARK: - Filters

struct ExpenseFilterState: Equatable {
    public var searchText: String = ""
    public var categoryId: UUID?
    public var merchantId: UUID?
    public var dateFrom: Date?
    public var dateTo: Date?
    public var minAmount: Decimal?
    public var maxAmount: Decimal?
    public var recurringOnly: Bool = false
    public var subscriptionLikeOnly: Bool = false
    public var refundsOnly: Bool = false
    public var heatZoneBucket: String?

    public var isActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || categoryId != nil
            || merchantId != nil
            || dateFrom != nil
            || dateTo != nil
            || minAmount != nil
            || maxAmount != nil
            || recurringOnly
            || subscriptionLikeOnly
            || refundsOnly
            || heatZoneBucket != nil
    }
}

enum ExpenseSearchScope: String, CaseIterable, Identifiable {
    case all
    case recurring
    case subscriptions
    case refunds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .recurring: return "Recurring"
        case .subscriptions: return "Subscriptions"
        case .refunds: return "Refunds"
        }
    }
}

// MARK: - Timeline

enum ExpenseTimelineSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This week"
    case lastWeek = "Last week"
    case thisMonth = "This month"
    case lastMonth = "Last month"
    case older = "Earlier"

    public var id: String { rawValue }
}

struct ExpenseTimelineGroup: Identifiable, Equatable {
    public let section: ExpenseTimelineSection
    public let records: [ExpenseRecord]

    public var id: String { section.rawValue }
}

enum ExpenseTimelineGrouper {
    static func group(_ records: [ExpenseRecord], calendar: Calendar = .current) -> [ExpenseTimelineGroup] {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek),
              let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth) else {
            return records.isEmpty ? [] : [ExpenseTimelineGroup(section: .older, records: records)]
        }

        var buckets: [ExpenseTimelineSection: [ExpenseRecord]] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            let section: ExpenseTimelineSection
            if day >= startOfToday {
                section = .today
            } else if day >= startOfYesterday {
                section = .yesterday
            } else if record.date >= startOfWeek {
                section = .thisWeek
            } else if record.date >= startOfLastWeek {
                section = .lastWeek
            } else if record.date >= startOfMonth {
                section = .thisMonth
            } else if record.date >= startOfLastMonth {
                section = .lastMonth
            } else {
                section = .older
            }
            buckets[section, default: []].append(record)
        }

        return ExpenseTimelineSection.allCases.compactMap { section in
            guard let items = buckets[section], !items.isEmpty else { return nil }
            return ExpenseTimelineGroup(section: section, records: items)
        }
    }
}

// MARK: - Category seeding

enum ExpenseCategoryCatalog {
    static let systemDefinitions: [(TransactionCategory, icon: String, color: String)] = [
        (.groceries, "cart.fill", "green"),
        (.restaurants, "fork.knife", "orange"),
        (.transport, "car.fill", "blue"),
        (.subscriptions, "arrow.triangle.2.circlepath", "purple"),
        (.housing, "house.fill", "brown"),
        (.income, "banknote.fill", "mint"),
        (.other, "square.grid.2x2.fill", "gray")
    ]
}

// MARK: - Brain Output Structs for 120fps UI

public struct ExpenseInteractionDisplay {
    public var header: ExpensesHeaderDisplay
    public var sections: [ExpenseSectionDisplay]
    public var summary: ExpensesSummaryDisplay
    
    public static let empty = ExpenseInteractionDisplay(
        header: ExpensesHeaderDisplay(totalSpent: 0, changeVsLastMonth: 0, biggestCategory: nil, biggestMerchant: nil, sparklinePoints: [], microInsight: nil),
        sections: [],
        summary: ExpensesSummaryDisplay(totalSpent: 0, categoryBreakdown: [], merchantBreakdown: [], trendPoints: [], prediction: nil)
    )
}

public struct ExpensesHeaderDisplay {
    public var totalSpent: Double
    public var changeVsLastMonth: Double
    public var biggestCategory: String?
    public var biggestMerchant: String?
    public var sparklinePoints: [Double]
    public var microInsight: String?
}

public struct ExpenseSectionDisplay: Identifiable {
    public var id: String { title }
    public var title: String
    public var microInsight: String?
    public var expenses: [ExpenseRowDisplay]
}

public struct ExpenseRowDisplay: Identifiable {
    public var id: UUID
    public var name: String
    public var amount: Double
    public var amountFormatted: String
    public var date: Date
    public var category: String?
    public var merchant: String?
    public var heatZone: String?
    public var habitSignature: String?
    public var emotion: String?
    public var context: String?
}

public struct ExpensesSummaryDisplay {
    public var totalSpent: Double
    public var categoryBreakdown: [(String, Double)]
    public var merchantBreakdown: [(String, Double)]
    public var trendPoints: [Double]
    public var prediction: String?
}
