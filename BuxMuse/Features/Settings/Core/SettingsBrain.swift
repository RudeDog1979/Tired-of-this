//
//  SettingsBrain.swift
//  BuxMuse
//
//  BuxMuse Brain Display & Normalization layer for Settings Cockpit.
//  Contains zero SwiftUI elements, only pure Swift structures.
//

import Foundation

public enum SettingsDestinationType: String, Codable, CaseIterable {
    case profile
    case appearance
    case regionCurrency
    case budgets
    case freelance
    case notifications
    case security
    case data
    case about
}

public struct SettingsRowDisplay: Identifiable, Equatable {
    public var id: String { title }
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let hexColor: String // Hex string to resolve to SwiftUI color safely
    public let trailingText: String?
    public let destination: SettingsDestinationType
    
    public init(title: String, subtitle: String, iconName: String, hexColor: String, trailingText: String? = nil, destination: SettingsDestinationType) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.hexColor = hexColor
        self.trailingText = trailingText
        self.destination = destination
    }
}

public struct SettingsSectionDisplay: Identifiable, Equatable {
    public var id: String { title }
    public let title: String
    public let rows: [SettingsRowDisplay]
    
    public init(title: String, rows: [SettingsRowDisplay]) {
        self.title = title
        self.rows = rows
    }
}

public struct SettingsOverviewDisplay: Equatable {
    public let sections: [SettingsSectionDisplay]
    
    public init(sections: [SettingsSectionDisplay]) {
        self.sections = sections
    }
}

@MainActor
public final class SettingsBrain {
    
    public static func generateOverview(
        store: SettingsStore,
        currentThemeName: String,
        activeCurrencyCode: String,
        activeCurrencyFlag: String
    ) -> SettingsOverviewDisplay {
        
        // 1. General Section
        let profileSubtitle = store.userDisplayName ?? "Configure display preferences"
        let preferredStyle = store.preferredNameStyle == .firstName ? "First Name" : "Full Name"
        
        let profileRow = SettingsRowDisplay(
            title: "Profile",
            subtitle: "\(profileSubtitle) · \(preferredStyle)",
            iconName: "person.crop.circle.fill",
            hexColor: "#FF5E5B", // Beautiful Coral
            trailingText: store.userDisplayName,
            destination: .profile
        )
        
        let appearanceRow = SettingsRowDisplay(
            title: "Appearance & Themes",
            subtitle: "Accent, glassmorphism, motion",
            iconName: "paintpalette.fill",
            hexColor: "#00E5FF", // Neon Blue
            trailingText: currentThemeName,
            destination: .appearance
        )
        
        let regionRow = SettingsRowDisplay(
            title: "Currency & Region",
            subtitle: "Currency code, formatting",
            iconName: "globe",
            hexColor: "#BF5AF2", // Purple
            trailingText: "\(activeCurrencyFlag) \(activeCurrencyCode)",
            destination: .regionCurrency
        )
        
        let generalSection = SettingsSectionDisplay(
            title: "GENERAL",
            rows: [profileRow, appearanceRow, regionRow]
        )
        
        // 2. Finance Rules Section
        let activeBudgetCount = store.customBudgetProfiles.count
        let budgetModeDesc: String
        switch store.budgetingMode {
        case .simple: budgetModeDesc = "Simple"
        case .envelope: budgetModeDesc = "Envelope"
        case .custom: budgetModeDesc = "Custom"
        }
        let budgetSubtitle = "Mode: \(budgetModeDesc) · \(activeBudgetCount) Profile\(activeBudgetCount == 1 ? "" : "s")"
        
        let budgetRow = SettingsRowDisplay(
            title: "Budgets & Custom Budgets",
            subtitle: budgetSubtitle,
            iconName: "chart.pie.fill",
            hexColor: "#30D158", // Bright Green
            trailingText: budgetModeDesc,
            destination: .budgets
        )
        
        let freelanceStatus = store.freelanceEnabled ? "Enabled" : "Disabled"
        let freelanceRow = SettingsRowDisplay(
            title: "Freelance Hub",
            subtitle: "Business profile, invoices, tax",
            iconName: "briefcase.fill",
            hexColor: "#FF9F0A", // Orange
            trailingText: freelanceStatus,
            destination: .freelance
        )
        
        let rulesSection = SettingsSectionDisplay(
            title: "BUX RULES",
            rows: [budgetRow, freelanceRow]
        )
        
        // 3. Security & Access Section
        let notifyStatus = store.notificationsEnabled ? "On" : "Off"
        let notifyRow = SettingsRowDisplay(
            title: "Notifications",
            subtitle: "Alerts, bill reminders (\(notifyStatus))",
            iconName: "bell.fill",
            hexColor: "#FF3B30", // Red
            trailingText: notifyStatus,
            destination: .notifications
        )
        
        let securityRow = SettingsRowDisplay(
            title: "Security & App Lock",
            subtitle: "Face ID, PIN passcode",
            iconName: "lock.fill",
            hexColor: "#0A84FF", // Blue
            trailingText: store.biometricLockEnabled ? "Biometrics" : (store.hasAppPasscode ? "PIN Code" : "Off"),
            destination: .security
        )
        
        let securitySection = SettingsSectionDisplay(
            title: "SECURITY & NOTIFICATIONS",
            rows: [notifyRow, securityRow]
        )
        
        // 4. Data Control Section
        let dataRow = SettingsRowDisplay(
            title: "Data & Export",
            subtitle: "Backups, export JSON, delete account",
            iconName: "arrow.down.doc.fill",
            hexColor: "#E0C3FC", // Lavender
            destination: .data
        )
        
        let aboutRow = SettingsRowDisplay(
            title: "About",
            subtitle: "BuxMuse version, credits",
            iconName: "info.circle.fill",
            hexColor: "#8E8E93", // Gray
            trailingText: "v1.0.0",
            destination: .about
        )
        
        let dataSection = SettingsSectionDisplay(
            title: "SYSTEM & PRIVACY",
            rows: [dataRow, aboutRow]
        )
        
        return SettingsOverviewDisplay(sections: [generalSection, rulesSection, securitySection, dataSection])
    }
}
