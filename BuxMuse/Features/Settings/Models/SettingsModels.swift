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
}

public enum DefaultBudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"
    
    public var id: String { rawValue }
}

public enum AutoBackupFrequency: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    public var id: String { rawValue }
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
