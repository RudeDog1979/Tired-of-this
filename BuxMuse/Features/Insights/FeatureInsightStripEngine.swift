//
//  FeatureInsightStripEngine.swift
//  BuxMuse
//
//  Horizontal MAT strips for Dashboard Insights & Money Map.
//

import Foundation

public struct FeatureInsightStrip: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var value: String
    public var subtitle: String
    public var systemIcon: String
    public var accentColorName: String
    public var isFeatureEnabled: Bool
    public var hasData: Bool
    public var ctaLabel: String?

    public init(
        id: String,
        title: String,
        value: String,
        subtitle: String,
        systemIcon: String,
        accentColorName: String,
        isFeatureEnabled: Bool,
        hasData: Bool,
        ctaLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.systemIcon = systemIcon
        self.accentColorName = accentColorName
        self.isFeatureEnabled = isFeatureEnabled
        self.hasData = hasData
        self.ctaLabel = ctaLabel
    }
}

enum FeatureInsightStripEngine {
    static func buildStrips(
        transactions: [Transaction],
        burnout: BurnoutInsightData,
        projects: [StudioProject],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [FeatureInsightStrip] {
        let store = SettingsStore.shared
        var strips: [FeatureInsightStrip] = []

        // Payment sources
        let creditInsight = PaymentSourceInsightsEngine.generateInsights(transactions: transactions, locale: locale).first
        strips.append(
            FeatureInsightStrip(
                id: "payment_sources",
                title: BuxLocalizedString.string("Credit & BNPL", locale: locale),
                value: creditInsight?.value ?? BuxLocalizedString.string(
                    store.paymentSourceTrackingEnabled ? "Tag expenses" : "Off",
                    locale: locale
                ),
                subtitle: creditInsight?.description ?? BuxLocalizedString.string(
                    "Enable payment tagging in Settings",
                    locale: locale
                ),
                systemIcon: "creditcard.trianglebadge.exclamationmark",
                accentColorName: "orange",
                isFeatureEnabled: store.paymentSourceTrackingEnabled,
                hasData: creditInsight != nil,
                ctaLabel: store.paymentSourceTrackingEnabled
                    ? nil
                    : BuxLocalizedString.string("Settings → Payment Sources", locale: locale)
            )
        )

        // Dual cash
        let cashInsight = CashDigitalInsightsEngine.generateInsights(transactions: transactions, locale: locale).first
        strips.append(
            FeatureInsightStrip(
                id: "dual_cash",
                title: BuxLocalizedString.string("Cash Drawer", locale: locale),
                value: store.dualCashDrawerEnabled
                    ? "\(store.primaryLocalCurrency) \(String(format: "%.0f", store.cashLocalBalanceValue))"
                    : BuxLocalizedString.string("Off", locale: locale),
                subtitle: cashInsight?.description ?? BuxLocalizedString.string(
                    store.studioEnabled ? "Enable in Studio → Cash & Barter" : "Enable Studio first",
                    locale: locale
                ),
                systemIcon: "banknote.fill",
                accentColorName: "green",
                isFeatureEnabled: store.studioEnabled && store.dualCashDrawerEnabled,
                hasData: cashInsight != nil,
                ctaLabel: store.studioEnabled
                    ? BuxLocalizedString.string("Studio → Cash & Barter", locale: locale)
                    : BuxLocalizedString.string("Studio → Turn on", locale: locale)
            )
        )

        // Barter
        let barterInsight = BarterInsightsEngine.generateInsights(transactions: transactions, locale: locale).first
        strips.append(
            FeatureInsightStrip(
                id: "barter",
                title: BuxLocalizedString.string("Barter & Trade", locale: locale),
                value: barterInsight?.value ?? BuxLocalizedString.string("No trades", locale: locale),
                subtitle: barterInsight?.description ?? BuxLocalizedString.string(
                    "Log non-cash exchanges",
                    locale: locale
                ),
                systemIcon: "arrow.left.arrow.right.circle.fill",
                accentColorName: "orange",
                isFeatureEnabled: store.studioEnabled && store.barterLoggerEnabled,
                hasData: barterInsight != nil,
                ctaLabel: store.studioEnabled
                    ? BuxLocalizedString.string("Studio → Cash & Barter", locale: locale)
                    : BuxLocalizedString.string("Studio → Turn on", locale: locale)
            )
        )

        // Workspaces
        let workspaceInsight = WorkspaceInsightsEngine.generateInsights(transactions: transactions, locale: locale).first
        let workspaceLabel = HustleWorkspaceFilter.activeWorkspaceLabel()
            ?? BuxLocalizedString.string("All workspaces", locale: locale)
        strips.append(
            FeatureInsightStrip(
                id: "workspaces",
                title: BuxLocalizedString.string("Workspaces", locale: locale),
                value: store.sideHustleMatrixEnabled
                    ? workspaceLabel
                    : BuxLocalizedString.string("Off", locale: locale),
                subtitle: workspaceInsight?.description ?? BuxLocalizedString.string(
                    "Separate gigs or departments",
                    locale: locale
                ),
                systemIcon: "square.grid.2x2.fill",
                accentColorName: "purple",
                isFeatureEnabled: store.sideHustleMatrixEnabled,
                hasData: workspaceInsight != nil || HustleManager.shared.hustles.count > 1,
                ctaLabel: store.studioEnabled
                    ? BuxLocalizedString.string("Studio → Workspaces", locale: locale)
                    : BuxLocalizedString.string("Studio → Turn on", locale: locale)
            )
        )

        // Burnout / creative energy
        strips.append(
            FeatureInsightStrip(
                id: "burnout",
                title: BuxLocalizedString.string("Creative Energy", locale: locale),
                value: store.burnoutGuardEnabled
                    ? "\(Int(burnout.creativeEnergyPercent))%"
                    : BuxLocalizedString.string("Off", locale: locale),
                subtitle: store.burnoutGuardEnabled
                    ? BuxLocalizedString.format(
                        "%.1f h work · %.1f h sleep",
                        locale: locale,
                        burnout.workHours,
                        burnout.sleepHours
                    )
                    : BuxLocalizedString.string("Track workload & rest", locale: locale),
                systemIcon: "bolt.heart.fill",
                accentColorName: burnout.creativeEnergyPercent > 45 ? "green" : "orange",
                isFeatureEnabled: store.burnoutGuardEnabled,
                hasData: burnout.workHours > 0 || burnout.stressExpenseCount > 0,
                ctaLabel: store.studioEnabled
                    ? BuxLocalizedString.string("Studio → Workload & Energy", locale: locale)
                    : BuxLocalizedString.string("Studio → Turn on", locale: locale)
            )
        )

        // Scope radar (Pro)
        let scopeInsight = ScopeCreepInsightsEngine.generateInsights(projects: projects, locale: locale).first
        strips.append(
            FeatureInsightStrip(
                id: "scope_radar",
                title: BuxLocalizedString.string("Scope Radar", locale: locale),
                value: scopeInsight?.value ?? BuxLocalizedString.string("Clear", locale: locale),
                subtitle: scopeInsight?.description ?? BuxLocalizedString.string(
                    "Hours & revision guardrails",
                    locale: locale
                ),
                systemIcon: "scope",
                accentColorName: "red",
                isFeatureEnabled: store.studioEnabled && store.studioMode == .pro && store.antiScopeCreepEnabled,
                hasData: scopeInsight != nil,
                ctaLabel: store.studioMode == .pro
                    ? BuxLocalizedString.string("Studio → Scope Radar", locale: locale)
                    : BuxLocalizedString.string("Upgrade to Pro", locale: locale)
            )
        )

        return strips
    }
}
