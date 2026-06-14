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
    case categories
    case merchants
    case subscriptions
    case studio
    case workTools
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
    case debts
    case household
    case personalCloudSync
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
    public let hexColor: String
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

    public var opensSubscriptionHub: Bool {
        false
    }
}

public struct SettingsSectionDisplay: Identifiable, Equatable {
    public var id: String { title }
    public let title: String
    public let rows: [SettingsRowDisplay]
    public let footerKey: String?
    public let isAdvancedSection: Bool

    public init(
        title: String,
        rows: [SettingsRowDisplay],
        footerKey: String? = nil,
        isAdvancedSection: Bool = false
    ) {
        self.title = title
        self.rows = rows
        self.footerKey = footerKey
        self.isAdvancedSection = isAdvancedSection
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
        let profileSubtitle = store.userDisplayName
            ?? BuxLocalizedString.string("Configure display preferences", locale: interfaceLocale)
        let preferredStyle = BuxLocalizedString.string(
            String.LocalizationValue(stringLiteral: store.preferredNameStyle.rawValue),
            locale: interfaceLocale
        )

        let youSection = SettingsSectionDisplay(
            title: "You",
            rows: [
                SettingsRowDisplay(
                    title: "Profile",
                    subtitle: "\(profileSubtitle) · \(preferredStyle)",
                    iconName: "person.crop.circle.fill",
                    hexColor: "#FF5E5B",
                    trailingText: store.userDisplayName,
                    destination: .profile
                ),
                SettingsRowDisplay(
                    title: "Look & feel",
                    subtitle: "Theme, colors, motion",
                    iconName: "paintpalette.fill",
                    hexColor: "#00E5FF",
                    trailingText: currentThemeName,
                    destination: .appearance
                ),
                SettingsRowDisplay(
                    title: "Currency & language",
                    subtitle: "Currency code, formatting",
                    iconName: "globe",
                    hexColor: "#BF5AF2",
                    trailingText: "\(activeCurrencyFlag) \(activeCurrencyCode)",
                    destination: .regionCurrency
                )
            ]
        )

        let budgetModeName = store.budgetingMode.localizedDisplayName(locale: interfaceLocale)
        let budgetSubtitle = BuxLocalizedString.format(
            "%@ · %lld extra profiles",
            locale: interfaceLocale,
            budgetModeName,
            store.customBudgetProfiles.count
        )

        let moneySection = SettingsSectionDisplay(
            title: "Money",
            rows: [
                SettingsRowDisplay(
                    title: "Budget",
                    subtitle: budgetSubtitle,
                    iconName: "chart.pie.fill",
                    hexColor: "#30D158",
                    trailingText: budgetModeName,
                    destination: .budgets
                ),
                SettingsRowDisplay(
                    title: "Debts",
                    subtitle: store.consumerDebtEnabled
                        ? "Credit cards, loans, and payoff tracking"
                        : "Off — turn on to track what you owe",
                    iconName: "creditcard.fill",
                    hexColor: "#FF6B6B",
                    trailingText: Self.localizedOnOff(store.consumerDebtEnabled, locale: interfaceLocale),
                    destination: .debts
                ),
                SettingsRowDisplay(
                    title: "Household",
                    subtitle: store.householdCloudRecordName == nil
                        ? "Share expenses with family via iCloud"
                        : (store.householdDisplayName ?? "Active household"),
                    iconName: "person.2.circle.fill",
                    hexColor: "#4ECDC4",
                    trailingText: store.householdCloudRecordName == nil ? nil : store.householdDisplayName,
                    destination: .household
                )
            ]
        )

        let notifyStatus = Self.localizedOnOff(store.notificationsEnabled, locale: interfaceLocale)
        let alertsSection = SettingsSectionDisplay(
            title: "Alerts",
            rows: [
                SettingsRowDisplay(
                    title: "Notifications",
                    subtitle: BuxLocalizedString.format(
                        "Bill reminders & budget warnings (%@)",
                        locale: interfaceLocale,
                        notifyStatus
                    ),
                    iconName: "bell.fill",
                    hexColor: "#FF3B30",
                    trailingText: notifyStatus,
                    destination: .notifications
                )
            ]
        )

        let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let lockSummary: String = {
            if store.biometricLockEnabled {
                return BuxLocalizedString.string("Face ID / Touch ID", locale: interfaceLocale)
            }
            if store.hasAppPasscode {
                return BuxLocalizedString.string("PIN", locale: interfaceLocale)
            }
            return BuxLocalizedString.string("Off", locale: interfaceLocale)
        }()

        let privacySection = SettingsSectionDisplay(
            title: "Privacy & data",
            rows: [
                SettingsRowDisplay(
                    title: "Sync with iCloud",
                    subtitle: store.personalCloudSyncEnabled
                        ? "Stored in Apple's iCloud — BuxMuse cannot see it"
                        : "Sync across iPhone and iPad via Apple's iCloud",
                    iconName: "icloud.fill",
                    hexColor: "#007AFF",
                    trailingText: Self.localizedOnOff(store.personalCloudSyncEnabled, locale: interfaceLocale),
                    destination: .personalCloudSync
                ),
                SettingsRowDisplay(
                    title: "Backup & export",
                    subtitle: "Encrypted archive, export, restore",
                    iconName: "arrow.down.doc.fill",
                    hexColor: "#E0C3FC",
                    destination: .data
                ),
                SettingsRowDisplay(
                    title: "App lock",
                    subtitle: "Face ID, Touch ID, or PIN",
                    iconName: "lock.fill",
                    hexColor: "#0A84FF",
                    trailingText: lockSummary,
                    destination: .security
                ),
                SettingsRowDisplay(
                    title: "About BuxMuse",
                    subtitle: "Version, privacy, credits",
                    iconName: "info.circle.fill",
                    hexColor: "#8E8E93",
                    trailingText: "v\(marketingVersion)",
                    destination: .about
                )
            ],
            footerKey: "Your spending stays on this device unless you turn on iCloud sync (stored with Apple, not BuxMuse) or share a household."
        )

        var sections: [SettingsSectionDisplay] = [youSection, moneySection, alertsSection, privacySection]

        if store.studioEnabled {
            let studioStatus = Self.localizedOnOff(store.studioEnabled, locale: interfaceLocale)
            let workSection = SettingsSectionDisplay(
                title: "Work",
                rows: [
                    SettingsRowDisplay(
                        title: "Studio",
                        subtitle: "Business profile, invoices, tax",
                        iconName: "laptopcomputer",
                        hexColor: "#FF9F0A",
                        trailingText: studioStatus,
                        destination: .studio
                    ),
                    SettingsRowDisplay(
                        title: "Projects",
                        subtitle: workspaceSubtitle(store: store, locale: interfaceLocale),
                        iconName: "briefcase.fill",
                        hexColor: "#64D2FF",
                        destination: .hustles
                    ),
                    SettingsRowDisplay(
                        title: "Work tools",
                        subtitle: workToolsSubtitle(store: store, locale: interfaceLocale),
                        iconName: "wrench.and.screwdriver.fill",
                        hexColor: "#AC8E68",
                        destination: .workTools
                    )
                ]
            )
            sections.append(workSection)
        }

        let advancedSection = SettingsSectionDisplay(
            title: "Advanced",
            rows: [
                SettingsRowDisplay(
                    title: "Payment methods",
                    subtitle: "Tags for cards, PayPal, Klarna, and more",
                    iconName: "creditcard.fill",
                    hexColor: "#5856D6",
                    trailingText: Self.localizedOnOff(store.paymentSourceTrackingEnabled, locale: interfaceLocale),
                    destination: .paymentSources
                ),
                SettingsRowDisplay(
                    title: "Scope radar",
                    subtitle: "Catch unpaid scope creep early",
                    iconName: "scope",
                    hexColor: "#FF6482",
                    trailingText: Self.localizedOnOff(store.antiScopeCreepEnabled, locale: interfaceLocale),
                    destination: .scopeCreepRadar,
                    tier: .proOnly
                ),
                SettingsRowDisplay(
                    title: "Agreement scratchpad",
                    subtitle: "Draft client terms before you send",
                    iconName: "doc.text.fill",
                    hexColor: "#5E5CE6",
                    trailingText: Self.localizedOnOff(store.agreementScratchpadEnabled, locale: interfaceLocale),
                    destination: .agreementScratchpad,
                    tier: .proOnly
                ),
                SettingsRowDisplay(
                    title: "Workload & energy",
                    subtitle: "Burnout guard for heavy weeks",
                    iconName: "bolt.heart.fill",
                    hexColor: "#FF375F",
                    trailingText: Self.localizedOnOff(store.burnoutGuardEnabled, locale: interfaceLocale),
                    destination: .burnoutGuard
                )
            ],
            isAdvancedSection: true
        )
        sections.append(advancedSection)

        return SettingsOverviewDisplay(sections: sections)
    }

    private static func workspaceSubtitle(store: SettingsStore, locale: Locale) -> String {
        guard store.sideHustleMatrixEnabled else {
            return BuxLocalizedString.string("Off", locale: locale)
        }
        return store.studioMode == .pro
            ? BuxLocalizedString.string("On · Unlimited", locale: locale)
            : BuxLocalizedString.string("On · Up to 3", locale: locale)
    }

    private static func workToolsSubtitle(store: SettingsStore, locale: Locale) -> String {
        let parts = [
            store.dualCashDrawerEnabled ? BuxLocalizedString.string("Cash on", locale: locale) : nil,
            store.barterLoggerEnabled ? BuxLocalizedString.string("Barter on", locale: locale) : nil,
            store.autoLocationForMileage ? BuxLocalizedString.string("Mileage on", locale: locale) : nil
        ].compactMap { $0 }
        if parts.isEmpty {
            return BuxLocalizedString.string("Cash, barter, mileage, invoices", locale: locale)
        }
        return parts.joined(separator: " · ")
    }
}
