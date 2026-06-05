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
    case studio
    case invoicePayment
    case mileage
    case notifications
    case security
    case data
    case about
    case hustles
    case dualCashDrawer
    case barterLogger
    case scopeCreepRadar
    case agreementScratchpad
    case burnoutGuard
    case paymentSources
}

public enum SettingsRowTier: Equatable {
    case standard
    /// Pro-only — Simple users see PRO badge and upsell on tap.
    case proOnly
    /// Available on Simple with limits; Pro unlocks extras.
    case freemium
}

public struct SettingsRowDisplay: Identifiable, Equatable {
    public var id: String { title }
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let hexColor: String // Hex string to resolve to SwiftUI color safely
    public let trailingText: String?
    public let destination: SettingsDestinationType
    public let tier: SettingsRowTier
    
    public init(
        title: String,
        subtitle: String,
        iconName: String,
        hexColor: String,
        trailingText: String? = nil,
        destination: SettingsDestinationType,
        tier: SettingsRowTier = .standard
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.hexColor = hexColor
        self.trailingText = trailingText
        self.destination = destination
        self.tier = tier
    }

    public var showsProBadge: Bool {
        switch tier {
        case .proOnly: return true
        case .freemium: return true
        case .standard: return false
        }
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

    private static func localizedOnOff(_ isOn: Bool, locale: Locale) -> String {
        BuxLocalizedString.string(isOn ? "On" : "Off", locale: locale)
    }
    
    public static func generateOverview(
        store: SettingsStore,
        currentThemeName: String,
        activeCurrencyCode: String,
        activeCurrencyFlag: String,
        interfaceLocale: Locale
    ) -> SettingsOverviewDisplay {
        
        // 1. General Section
        let profileSubtitle = store.userDisplayName
            ?? BuxLocalizedString.string("Configure display preferences", locale: interfaceLocale)
        let preferredStyle = BuxLocalizedString.string(
            String.LocalizationValue(stringLiteral: store.preferredNameStyle.rawValue),
            locale: interfaceLocale
        )
        
        let profileRow = SettingsRowDisplay(
            title: "Profile",
            subtitle: "\(profileSubtitle) · \(preferredStyle)",
            iconName: "person.crop.circle.fill",
            hexColor: "#FF5E5B", // Beautiful Coral
            trailingText: store.userDisplayName,
            destination: .profile
        )
        
        let appearanceRow = SettingsRowDisplay(
            title: "Appearance & themes",
            subtitle: "Accent, glassmorphism, motion",
            iconName: "paintpalette.fill",
            hexColor: "#00E5FF", // Neon Blue
            trailingText: currentThemeName,
            destination: .appearance
        )
        
        let regionRow = SettingsRowDisplay(
            title: "Currency & region",
            subtitle: "Currency code, formatting",
            iconName: "globe",
            hexColor: "#BF5AF2", // Purple
            trailingText: "\(activeCurrencyFlag) \(activeCurrencyCode)",
            destination: .regionCurrency
        )
        
        let generalSection = SettingsSectionDisplay(
            title: "General",
            rows: [profileRow, appearanceRow, regionRow]
        )
        
        // 2. Finance Rules Section
        let activeBudgetCount = store.customBudgetProfiles.count
        let budgetModeName = store.budgetingMode.localizedDisplayName(locale: interfaceLocale)
        let budgetSubtitle = BuxLocalizedString.format(
            "Mode: %@ · %lld profiles",
            locale: interfaceLocale,
            budgetModeName,
            activeBudgetCount
        )
        
        let budgetRow = SettingsRowDisplay(
            title: "Budgets & custom budgets",
            subtitle: budgetSubtitle,
            iconName: "chart.pie.fill",
            hexColor: "#30D158", // Bright Green
            trailingText: budgetModeName,
            destination: .budgets
        )
        
        let studioStatus = Self.localizedOnOff(store.studioEnabled, locale: interfaceLocale)
        let studioRow = SettingsRowDisplay(
            title: "Studio",
            subtitle: "Business profile, invoices, tax",
            iconName: "laptopcomputer",
            hexColor: "#FF9F0A",
            trailingText: studioStatus,
            destination: .studio
        )

        let paymentSourcesRow = SettingsRowDisplay(
            title: "Payment sources",
            subtitle: "Visa, PayPal, Klarna tags for credit insights",
            iconName: "creditcard.fill",
            hexColor: "#5856D6",
            trailingText: Self.localizedOnOff(store.paymentSourceTrackingEnabled, locale: interfaceLocale),
            destination: .paymentSources
        )

        let expenseIntelligenceSection = SettingsSectionDisplay(
            title: "Expense intelligence",
            rows: [paymentSourcesRow]
        )

        let financeSection = SettingsSectionDisplay(
            title: "Finance",
            rows: [budgetRow, studioRow]
        )
        
        // 3. Security & Access Section
        let notifyStatus = Self.localizedOnOff(store.notificationsEnabled, locale: interfaceLocale)
        let notifyRow = SettingsRowDisplay(
            title: "Notifications",
            subtitle: BuxLocalizedString.format(
                "Alerts, bill reminders (%@)",
                locale: interfaceLocale,
                notifyStatus
            ),
            iconName: "bell.fill",
            hexColor: "#FF3B30", // Red
            trailingText: notifyStatus,
            destination: .notifications
        )
        
        let securityRow = SettingsRowDisplay(
            title: "Security & app lock",
            subtitle: "Face ID, PIN passcode",
            iconName: "lock.fill",
            hexColor: "#0A84FF", // Blue
            trailingText: store.biometricLockEnabled ? "Biometrics" : (store.hasAppPasscode ? "PIN Code" : "Off"),
            destination: .security
        )
        
        let securitySection = SettingsSectionDisplay(
            title: "Security & notifications",
            rows: [notifyRow, securityRow]
        )
        
        // 4. Data Control Section
        let dataRow = SettingsRowDisplay(
            title: "Backup & restore",
            subtitle: "Encrypted archive, export, full restore",
            iconName: "arrow.down.doc.fill",
            hexColor: "#E0C3FC",
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
            title: "System & privacy",
            rows: [dataRow, aboutRow]
        )
        
        return SettingsOverviewDisplay(sections: [generalSection, financeSection, expenseIntelligenceSection, securitySection, dataSection])
    }
}
