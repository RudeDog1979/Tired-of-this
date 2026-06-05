//
//  SettingsModels.swift
//  BuxMuse
//
//  Premium local settings configuration primitives & model schemas.
//

import Foundation

// MARK: - Enums

public enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var id: String { rawValue }
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
        BuxCatalogLabel.string(rawValue, locale: locale)
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
        localizedDisplayName(locale: locale)
    }
}

/// Simple-budget spend window (independent of calendar month when using mid-month / pay cycles).
public enum SimpleBudgetCycle: String, Codable, CaseIterable, Identifiable {
    case monthFirst = "Month starts on the 1st"
    case monthFifteenth = "Month starts on the 15th"
    case monthThirtieth = "Month starts on the 30th"
    case weekly = "Weekly"
    case biweekly = "Every two weeks"
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
    
    public init(id: UUID = UUID(), name: String, targetAmount: Decimal) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
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
    
    public init(
        id: UUID = UUID(),
        name: String,
        isActive: Bool = false,
        periodType: DefaultBudgetPeriod = .monthly,
        categories: [CustomBudgetCategory] = [],
        targetAmount: Decimal = 0,
        rolloverEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.periodType = periodType
        self.categories = categories
        self.targetAmount = targetAmount
        self.rolloverEnabled = rolloverEnabled
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

