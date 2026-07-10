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
    case subscription
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
    case appleWallet
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
                    title: "Subscription",
                    subtitle: subscriptionSettingsSubtitle(locale: interfaceLocale),
                    iconName: "sparkles",
                    hexColor: "#FFD60A",
                    trailingText: subscriptionSettingsTrailing(locale: interfaceLocale),
                    destination: .subscription
                ),
                SettingsRowDisplay(
                    title: "Look & feel",
                    subtitle: BuxCatalogLabel.string("Theme, colors, motion", locale: interfaceLocale),
                    iconName: "paintpalette.fill",
                    hexColor: "#00E5FF",
                    trailingText: currentThemeName,
                    destination: .appearance
                ),
                SettingsRowDisplay(
                    title: "Currency & language",
                    subtitle: BuxCatalogLabel.string("Currency code, formatting", locale: interfaceLocale),
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
                    title: "Apple Wallet Sync",
                    subtitle: store.appleWalletSyncEnabled
                        ? BuxCatalogLabel.string("Automatically sync and match transactions", locale: interfaceLocale)
                        : BuxCatalogLabel.string("Off — tap to connect Apple Wallet", locale: interfaceLocale),
                    iconName: "wallet.pass.fill",
                    hexColor: "#007AFF",
                    trailingText: Self.localizedOnOff(store.appleWalletSyncEnabled, locale: interfaceLocale),
                    destination: .appleWallet
                ),
                SettingsRowDisplay(
                    title: "Debts",
                    subtitle: store.consumerDebtEnabled
                        ? BuxCatalogLabel.string("Credit cards, loans, and payoff tracking", locale: interfaceLocale)
                        : BuxCatalogLabel.string("Off — turn on to track what you owe", locale: interfaceLocale),
                    iconName: "creditcard.fill",
                    hexColor: "#FF6B6B",
                    trailingText: Self.localizedOnOff(store.consumerDebtEnabled, locale: interfaceLocale),
                    destination: .debts
                ),
                SettingsRowDisplay(
                    title: "Household",
                    subtitle: store.householdCloudRecordName == nil
                        ? BuxCatalogLabel.string("Share expenses with family via iCloud", locale: interfaceLocale)
                        : (store.householdDisplayName ?? BuxCatalogLabel.string("Active household", locale: interfaceLocale)),
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
                        ? BuxCatalogLabel.string("Stored in Apple's iCloud — BuxMuse cannot see it", locale: interfaceLocale)
                        : BuxCatalogLabel.string("Sync across iPhone and iPad via Apple's iCloud", locale: interfaceLocale),
                    iconName: "icloud.fill",
                    hexColor: "#007AFF",
                    trailingText: Self.localizedOnOff(store.personalCloudSyncEnabled, locale: interfaceLocale),
                    destination: .personalCloudSync
                ),
                SettingsRowDisplay(
                    title: "Backup & export",
                    subtitle: BuxCatalogLabel.string("Encrypted archive, export, restore", locale: interfaceLocale),
                    iconName: "arrow.down.doc.fill",
                    hexColor: "#E0C3FC",
                    destination: .data
                ),
                SettingsRowDisplay(
                    title: "App lock",
                    subtitle: BuxCatalogLabel.string("Face ID, Touch ID, or PIN", locale: interfaceLocale),
                    iconName: "lock.fill",
                    hexColor: "#0A84FF",
                    trailingText: lockSummary,
                    destination: .security
                ),
                SettingsRowDisplay(
                    title: "About BuxMuse",
                    subtitle: BuxCatalogLabel.string("Version, privacy, credits", locale: interfaceLocale),
                    iconName: "info.circle.fill",
                    hexColor: "#8E8E93",
                    trailingText: "v\(marketingVersion)",
                    destination: .about
                )
            ],
            footerKey: "Your spending stays on this device unless you turn on iCloud sync (stored with Apple, not BuxMuse) or share a household."
        )

        var sections: [SettingsSectionDisplay] = [youSection, moneySection, alertsSection, privacySection]

        let purchaseManager = StudioPurchaseManager.shared
        var workRows: [SettingsRowDisplay] = [
            SettingsRowDisplay(
                title: "Studio",
                subtitle: studioSettingsSubtitle(store: store, locale: interfaceLocale),
                iconName: "laptopcomputer",
                hexColor: "#FF9F0A",
                trailingText: studioSettingsTrailing(store: store, locale: interfaceLocale),
                destination: .studio
            )
        ]
        if store.studioEnabled && purchaseManager.hasSimpleStudio {
            workRows.append(contentsOf: [
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
            ])
        }
        sections.append(SettingsSectionDisplay(title: "Work", rows: workRows))

        let advancedSection = SettingsSectionDisplay(
            title: "Advanced",
            rows: [
                SettingsRowDisplay(
                    title: "Payment methods",
                    subtitle: BuxCatalogLabel.string("Tags for cards, PayPal, Klarna, and more", locale: interfaceLocale),
                    iconName: "creditcard.fill",
                    hexColor: "#5856D6",
                    trailingText: Self.localizedOnOff(store.paymentSourceTrackingEnabled, locale: interfaceLocale),
                    destination: .paymentSources
                ),
                SettingsRowDisplay(
                    title: "Scope radar",
                    subtitle: BuxCatalogLabel.string("Catch unpaid scope creep early", locale: interfaceLocale),
                    iconName: "scope",
                    hexColor: "#FF6482",
                    trailingText: Self.localizedOnOff(store.antiScopeCreepEnabled, locale: interfaceLocale),
                    destination: .scopeCreepRadar,
                    tier: .proOnly
                ),
                SettingsRowDisplay(
                    title: "Agreement scratchpad",
                    subtitle: BuxCatalogLabel.string("Draft client terms before you send", locale: interfaceLocale),
                    iconName: "doc.text.fill",
                    hexColor: "#5E5CE6",
                    trailingText: Self.localizedOnOff(store.agreementScratchpadEnabled, locale: interfaceLocale),
                    destination: .agreementScratchpad,
                    tier: .proOnly
                ),
                SettingsRowDisplay(
                    title: "Workload & energy",
                    subtitle: BuxCatalogLabel.string("Burnout guard for heavy weeks", locale: interfaceLocale),
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

    private static func subscriptionSettingsSubtitle(locale: Locale) -> String {
        let purchaseManager = StudioPurchaseManager.shared
        if purchaseManager.baseInIntroductoryOffer || purchaseManager.isLegacyLocalTrialActive {
            return BuxLocalizedString.format(
                "Trial · %lld days left",
                locale: locale,
                Int64(purchaseManager.premiumTrialDaysRemaining)
            )
        }
        if purchaseManager.hasProStudio {
            return BuxLocalizedString.string("BuxMuse Pro is active", locale: locale)
        }
        if purchaseManager.baseSubscriptionActive {
            return BuxLocalizedString.string("BuxMuse Standard is active", locale: locale)
        }
        if purchaseManager.baseIntroOfferEligible {
            return BuxStoreKitIntroOfferCopy.trialAvailableSettingsSubtitle(
                for: purchaseManager.product(for: .standardMonthly),
                locale: locale
            )
        }
        return BuxLocalizedString.string("Standard or Pro plans", locale: locale)
    }

    private static func subscriptionSettingsTrailing(locale: Locale) -> String {
        let purchaseManager = StudioPurchaseManager.shared
        if purchaseManager.baseInIntroductoryOffer || purchaseManager.isLegacyLocalTrialActive {
            return BuxLocalizedString.format("%lldd", locale: locale, Int64(purchaseManager.premiumTrialDaysRemaining))
        }
        if purchaseManager.baseSubscriptionActive || purchaseManager.hasProStudio {
            return BuxLocalizedString.string("Active", locale: locale)
        }
        if purchaseManager.baseIntroOfferEligible {
            return BuxLocalizedString.string("Try free", locale: locale)
        }
        return BuxLocalizedString.string("Subscribe", locale: locale)
    }

    private static func studioSettingsSubtitle(store: SettingsStore, locale: Locale) -> String {
        let purchaseManager = StudioPurchaseManager.shared
        if !purchaseManager.hasActiveSubscription {
            return BuxLocalizedString.string("Included with BuxMuse Standard", locale: locale)
        }
        if purchaseManager.hasProStudio {
            return BuxLocalizedString.string("Pro — business profile, invoices, tax", locale: locale)
        }
        if purchaseManager.hasSimpleStudio {
            return BuxLocalizedString.string("Simple — invoices and work ledger", locale: locale)
        }
        return BuxLocalizedString.string("Included with Standard", locale: locale)
    }

    private static func studioSettingsTrailing(store: SettingsStore, locale: Locale) -> String {
        let purchaseManager = StudioPurchaseManager.shared
        if !purchaseManager.hasSimpleStudio {
            return BuxLocalizedString.string("Get", locale: locale)
        }
        if purchaseManager.hasProStudio {
            return BuxLocalizedString.string("Pro", locale: locale)
        }
        if store.studioEnabled {
            return BuxLocalizedString.string("Simple", locale: locale)
        }
        return BuxLocalizedString.string("Off", locale: locale)
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
