//
//  SettingsModels.swift
//  BuxMuse
//
//  Premium local settings configuration primitives & model schemas.
//

import Foundation
import SwiftUI

// MARK: - Enums

public enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public enum PreferredNameStyle: String, Codable, CaseIterable, Identifiable {
    case firstName = "First Name Only"
    case fullName = "Full Name"
    
    public var id: String { rawValue }
}

public enum BudgetingMode: String, Codable, CaseIterable, Identifiable {
    case simple = "Simple"
    case envelope = "Envelope"
    case custom = "Custom"

    public var id: String { rawValue }

    public func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        catalogLabel(locale: locale)
    }

    public func catalogLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        switch self {
        case .simple, .custom:
            return BuxCatalogLabel.string("Standard", locale: locale)
        case .envelope:
            return BuxCatalogLabel.string(rawValue, locale: locale)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Simple", "Income-based":
            self = .simple
        case "Envelope":
            self = .envelope
        case "Custom":
            self = .custom
        default:
            self = .simple
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .simple, .custom:
            try container.encode("Simple")
        case .envelope:
            try container.encode("Envelope")
        }
    }
}

public enum DefaultBudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"
    
    public var id: String { rawValue }
}

public enum IncomeFundingSource: String, Codable, CaseIterable, Identifiable {
    case salary = "Salary"
    case other = "Other"
    
    public var id: String { rawValue }
    
    public func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(rawValue, locale: locale)
    }
    
    public func catalogLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        switch self {
        case .salary:
            return BuxCatalogLabel.string("Paycheck & salary", locale: locale)
        case .other:
            return BuxCatalogLabel.string("Freelance & other", locale: locale)
        }
    }
}

/// Simple-budget spend window (independent of calendar month when using mid-month / pay cycles).
public enum SimpleBudgetCycle: String, Codable, CaseIterable, Identifiable {
    case monthFirst = "Month starts on the 1st"
    case monthFifteenth = "Month starts on the 15th"
    case monthThirtieth = "Month starts on the 30th"
    case weekly = "Weekly"
    case biweekly = "Every two weeks"
    case daily = "Daily"
    case custom = "Custom start date"

    public var id: String { rawValue }

    public var needsAnchorDate: Bool {
        switch self {
        case .biweekly, .custom: return true
        default: return false
        }
    }

    public func catalogLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        switch self {
        case .monthFirst:
            return BuxCatalogLabel.string("Monthly (1st)", locale: locale)
        case .monthFifteenth:
            return BuxCatalogLabel.string("Monthly (15th)", locale: locale)
        case .monthThirtieth:
            return BuxCatalogLabel.string("Monthly (30th)", locale: locale)
        case .weekly:
            return BuxCatalogLabel.string("Weekly", locale: locale)
        case .biweekly:
            return BuxCatalogLabel.string("Bi-weekly", locale: locale)
        case .daily:
            return BuxCatalogLabel.string("Daily", locale: locale)
        case .custom:
            return BuxCatalogLabel.string("Custom Date", locale: locale)
        }
    }
}

public enum AutoBackupFrequency: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"
    
    public var id: String { rawValue }

    /// Seconds between automatic local backup writes.
    public var backupInterval: TimeInterval {
        switch self {
        case .off: return 0
        case .weekly: return 604_800
        case .monthly: return 2_592_000
        case .custom: return 259_200 // default 3 days
        }
    }
}

public enum WeekStartDay: String, Codable, CaseIterable, Identifiable {
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    
    public var id: String { rawValue }

    /// `Calendar.firstWeekday` value (1 = Sunday … 7 = Saturday).
    public var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

// MARK: - Custom Budget Sub-models

public struct CustomBudgetCategory: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var targetAmount: Decimal
    public var categoryId: UUID?
    public var systemCategoryRaw: String?

    public init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        categoryId: UUID? = nil,
        systemCategoryRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.categoryId = categoryId
        self.systemCategoryRaw = systemCategoryRaw
    }
}

public struct CustomBudgetProfile: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var isActive: Bool
    public var periodType: DefaultBudgetPeriod
    public var categories: [CustomBudgetCategory]
    public var targetAmount: Decimal
    public var rolloverEnabled: Bool
    /// User-configurable warning threshold (1–100). Default 80%.
    public var approachingThresholdPercent: Int

    public init(
        id: UUID = UUID(),
        name: String,
        isActive: Bool = false,
        periodType: DefaultBudgetPeriod = .monthly,
        categories: [CustomBudgetCategory] = [],
        targetAmount: Decimal = 0,
        rolloverEnabled: Bool = false,
        approachingThresholdPercent: Int = 80
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.periodType = periodType
        self.categories = categories
        self.targetAmount = targetAmount
        self.rolloverEnabled = rolloverEnabled
        self.approachingThresholdPercent = approachingThresholdPercent
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isActive, periodType, categories, targetAmount, rolloverEnabled, approachingThresholdPercent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        periodType = try container.decode(DefaultBudgetPeriod.self, forKey: .periodType)
        categories = try container.decode([CustomBudgetCategory].self, forKey: .categories)
        targetAmount = try container.decode(Decimal.self, forKey: .targetAmount)
        rolloverEnabled = try container.decodeIfPresent(Bool.self, forKey: .rolloverEnabled) ?? false
        approachingThresholdPercent = try container.decodeIfPresent(Int.self, forKey: .approachingThresholdPercent) ?? 80
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(periodType, forKey: .periodType)
        try container.encode(categories, forKey: .categories)
        try container.encode(targetAmount, forKey: .targetAmount)
        try container.encode(rolloverEnabled, forKey: .rolloverEnabled)
        try container.encode(approachingThresholdPercent, forKey: .approachingThresholdPercent)
    }
}

public enum GreetingFontStyle: String, Codable, CaseIterable, Identifiable {
    case playful = "Playful"
    case professional = "Professional"
    
    public var id: String { rawValue }

    public func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(rawValue, locale: locale)
    }
}

