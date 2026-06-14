//
//  ExpenseModels.swift
//  BuxMuse
//
//  Expense domain models for SwiftData-backed expenses UI.
//

import Foundation

// MARK: - Category split

struct ExpenseSplitLineRecord: Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public var categoryId: UUID?
    public var categoryRaw: String
    public var amountValue: Decimal
    public var sortOrder: Int

    public var transactionCategory: TransactionCategory {
        TransactionCategory(rawValue: categoryRaw) ?? .other
    }

    public init(
        id: UUID = UUID(),
        categoryId: UUID? = nil,
        categoryRaw: String,
        amountValue: Decimal,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryRaw = categoryRaw
        self.amountValue = amountValue
        self.sortOrder = sortOrder
    }

    public static func from(_ entity: ExpenseSplitLineEntity) -> ExpenseSplitLineRecord {
        ExpenseSplitLineRecord(
            id: entity.id,
            categoryId: entity.categoryId,
            categoryRaw: entity.categoryRaw,
            amountValue: entity.amountValue,
            sortOrder: entity.sortOrder
        )
    }
}

/// UI draft line for split editor — persisted as `ExpenseSplitLineRecord`.
public struct ExpenseCategorySplitLine: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public var categoryId: UUID?
    public var categoryRaw: String
    public var amountString: String

    public init(
        id: UUID = UUID(),
        categoryId: UUID? = nil,
        categoryRaw: String = TransactionCategory.other.rawValue,
        amountString: String = ""
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryRaw = categoryRaw
        self.amountString = amountString
    }

    public var amountDecimal: Decimal? {
        let cleaned = amountString.replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: cleaned), value > 0 else { return nil }
        return value
    }

    public var transactionCategory: TransactionCategory {
        TransactionCategory(rawValue: categoryRaw) ?? .other
    }

    func toSplitLineRecord(sortOrder: Int) -> ExpenseSplitLineRecord? {
        guard let amount = amountDecimal else { return nil }
        return ExpenseSplitLineRecord(
            id: id,
            categoryId: categoryId,
            categoryRaw: categoryRaw,
            amountValue: amount,
            sortOrder: sortOrder
        )
    }

    static func from(_ record: ExpenseSplitLineRecord) -> ExpenseCategorySplitLine {
        ExpenseCategorySplitLine(
            id: record.id,
            categoryId: record.categoryId,
            categoryRaw: record.categoryRaw,
            amountString: NSDecimalNumber(decimal: record.amountValue).stringValue
        )
    }
}

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
    public var hustleId: UUID?
    public var paymentMethod: String?
    public var isBarterExchange: Bool
    public var barterGoodsGiven: String?
    public var barterGoodsReceived: String?
    public var barterEstimatedValue: Decimal?
    public var bridgeGroupId: UUID?
    public var bridgeKind: String?
    public var bridgeRole: String?
    public var bridgeSharePercent: Double?
    public var bridgePeerExpenseId: UUID?
    public var bridgeCounterpartyHustleId: UUID?
    public var isCategorySplit: Bool
    public var splitLines: [ExpenseSplitLineRecord]
    public var householdScope: HouseholdScope

    public var synergyBridgeKind: SynergyBridgeKind? {
        bridgeKind.flatMap { SynergyBridgeKind(rawValue: $0) }
    }

    public var amountDouble: Double {
        NSDecimalNumber(decimal: amountValue).doubleValue
    }

    public var transactionCategory: TransactionCategory {
        TransactionCategory(rawValue: categoryRaw) ?? .other
    }

    /// Resolves custom category name when `categoryId` points at a user tag; otherwise system label.
    public func resolvedCategoryLabel(
        categoriesById: [UUID: ExpenseCategoryRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> String {
        if let categoryId,
           let tag = categoriesById[categoryId] {
            return tag.localizedDisplayName(locale: locale)
        }
        return transactionCategory.localizedDisplayName(locale: locale)
    }

    public var isRefund: Bool {
        amountValue > 0 && transactionCategory != .income
    }

    /// Outflow expenses only — income and refunds are excluded from spend totals.
    public var isSpendingOutflow: Bool {
        amountValue < 0
    }

    public var spendingAmountDouble: Double {
        guard isSpendingOutflow else { return 0 }
        return abs(amountDouble)
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
        merchantName: String,
        hustleId: UUID? = nil,
        paymentMethod: String? = nil,
        isBarterExchange: Bool = false,
        barterGoodsGiven: String? = nil,
        barterGoodsReceived: String? = nil,
        barterEstimatedValue: Decimal? = nil,
        bridgeGroupId: UUID? = nil,
        bridgeKind: String? = nil,
        bridgeRole: String? = nil,
        bridgeSharePercent: Double? = nil,
        bridgePeerExpenseId: UUID? = nil,
        bridgeCounterpartyHustleId: UUID? = nil,
        isCategorySplit: Bool = false,
        splitLines: [ExpenseSplitLineRecord] = [],
        householdScope: HouseholdScope = .personal
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
        self.hustleId = hustleId
        self.paymentMethod = paymentMethod
        self.isBarterExchange = isBarterExchange
        self.barterGoodsGiven = barterGoodsGiven
        self.barterGoodsReceived = barterGoodsReceived
        self.barterEstimatedValue = barterEstimatedValue
        self.bridgeGroupId = bridgeGroupId
        self.bridgeKind = bridgeKind
        self.bridgeRole = bridgeRole
        self.bridgeSharePercent = bridgeSharePercent
        self.bridgePeerExpenseId = bridgePeerExpenseId
        self.bridgeCounterpartyHustleId = bridgeCounterpartyHustleId
        self.isCategorySplit = isCategorySplit
        self.splitLines = splitLines
        self.householdScope = householdScope
    }

    public func toTransaction() -> Transaction {
        Transaction(
            id: id,
            date: date,
            amount: MoneyAmount(value: amountValue, currencyCode: currencyCode),
            merchantName: name,
            category: transactionCategory,
            notes: notes,
            emotion: emotion,
            isSubscriptionLike: isSubscriptionLike,
            isTrial: isTrial,
            nextExpectedDate: nextExpectedDate,
            subscriptionStartDate: subscriptionStartDate,
            trialEndDate: trialEndDate,
            hustleId: hustleId,
            paymentMethod: paymentMethod,
            isBarterExchange: isBarterExchange,
            barterGoodsGiven: barterGoodsGiven,
            barterGoodsReceived: barterGoodsReceived,
            barterEstimatedValue: barterEstimatedValue,
            bridgeGroupId: bridgeGroupId,
            bridgeKind: bridgeKind,
            bridgeRole: bridgeRole,
            bridgeSharePercent: bridgeSharePercent,
            bridgePeerExpenseId: bridgePeerExpenseId,
            bridgeCounterpartyHustleId: bridgeCounterpartyHustleId
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
            merchantName: entity.merchantName.isEmpty ? entity.name : entity.merchantName,
            hustleId: entity.hustleId,
            paymentMethod: entity.paymentMethod,
            isBarterExchange: entity.isBarterExchange,
            barterGoodsGiven: entity.barterGoodsGiven,
            barterGoodsReceived: entity.barterGoodsReceived,
            barterEstimatedValue: entity.barterEstimatedValue,
            bridgeGroupId: entity.bridgeGroupId,
            bridgeKind: entity.bridgeKind,
            bridgeRole: entity.bridgeRole,
            bridgeSharePercent: entity.bridgeSharePercent,
            bridgePeerExpenseId: entity.bridgePeerExpenseId,
            bridgeCounterpartyHustleId: entity.bridgeCounterpartyHustleId,
            isCategorySplit: entity.isCategorySplit,
            splitLines: entity.splitLines
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { ExpenseSplitLineRecord.from($0) },
            householdScope: HouseholdScope(rawValue: entity.householdScopeRaw) ?? .personal
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
            merchantName: transaction.merchantName,
            hustleId: transaction.hustleId,
            paymentMethod: transaction.paymentMethod,
            isBarterExchange: transaction.isBarterExchange,
            barterGoodsGiven: transaction.barterGoodsGiven,
            barterGoodsReceived: transaction.barterGoodsReceived,
            barterEstimatedValue: transaction.barterEstimatedValue,
            bridgeGroupId: transaction.bridgeGroupId,
            bridgeKind: transaction.bridgeKind,
            bridgeRole: transaction.bridgeRole,
            bridgeSharePercent: transaction.bridgeSharePercent,
            bridgePeerExpenseId: transaction.bridgePeerExpenseId,
            bridgeCounterpartyHustleId: transaction.bridgeCounterpartyHustleId
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
    public var disambiguator: String
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
            disambiguator: entity.disambiguator,
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
    public var systemCategoryRaw: String?

    public var isActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || categoryId != nil
            || systemCategoryRaw != nil
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
        (.entertainment, "film.fill", "pink"),
        (.shopping, "bag.fill", "indigo"),
        (.health, "heart.fill", "red"),
        (.utilities, "bolt.fill", "yellow"),
        (.travel, "airplane", "cyan"),
        (.education, "book.fill", "teal"),
        (.personal, "sparkles", "purple"),
        (.income, "banknote.fill", "mint"),
        (.other, "square.grid.2x2.fill", "gray")
    ]

    static func category(forDisplayName name: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> TransactionCategory? {
        TransactionCategory.allCases.first { category in
            category.displayName.caseInsensitiveCompare(name) == .orderedSame
                || category.localizedDisplayName(locale: locale).caseInsensitiveCompare(name) == .orderedSame
        }
    }

    static func catalogColorName(
        forDisplayName name: String,
        customCategories: [ExpenseCategoryRecord] = [],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> String {
        if let custom = matchingCustomCategory(named: name, in: customCategories, locale: locale) {
            return custom.color
        }
        guard let category = category(forDisplayName: name, locale: locale),
              let def = systemDefinitions.first(where: { $0.0 == category }) else {
            return "gray"
        }
        return def.color
    }

    static func icon(
        forDisplayName name: String,
        customCategories: [ExpenseCategoryRecord] = [],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> String {
        if let custom = matchingCustomCategory(named: name, in: customCategories, locale: locale) {
            return custom.icon
        }
        guard let category = category(forDisplayName: name, locale: locale),
              let def = systemDefinitions.first(where: { $0.0 == category }) else {
            return ExpenseCategoryIconCatalog.suggestedIcon(for: name)
        }
        return def.icon
    }

    static func matchingCustomCategory(
        named name: String,
        in customCategories: [ExpenseCategoryRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> ExpenseCategoryRecord? {
        customCategories.first { record in
            guard record.isCustom else { return false }
            return record.name.caseInsensitiveCompare(name) == .orderedSame
                || record.localizedDisplayName(locale: locale).caseInsensitiveCompare(name) == .orderedSame
        }
    }
}

// MARK: - Brain Output Structs for 120fps UI

public struct ExpenseInteractionDisplay {
    public var header: ExpensesHeaderDisplay
    public var sections: [ExpenseSectionDisplay]
    public var summary: ExpensesSummaryDisplay
    
    public static let empty = ExpenseInteractionDisplay(
        header: ExpensesHeaderDisplay(totalSpent: 0, changeVsLastMonth: 0, monthlyTransactionCount: 0, biggestCategory: nil, biggestMerchant: nil, sparklinePoints: [], microInsight: nil),
        sections: [],
        summary: ExpensesSummaryDisplay(totalSpent: 0, categoryBreakdown: [], merchantBreakdown: [], trendPoints: [], prediction: nil)
    )
}

public struct ExpensesHeaderDisplay {
    public var totalSpent: Double
    public var changeVsLastMonth: Double
    public var monthlyTransactionCount: Int
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
    public var emotionSymbol: String?
    public var context: String?
    public var hustleId: UUID?
    public var isUnassignedWorkspace: Bool
    public var workspaceLabel: String?
    public var bridgeBadge: String?
}

public struct ExpensesSummaryDisplay {
    public var totalSpent: Double
    public var categoryBreakdown: [(String, Double)]
    public var merchantBreakdown: [(String, Double)]
    public var trendPoints: [Double]
    public var prediction: String?
}
