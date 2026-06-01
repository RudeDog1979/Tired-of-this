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
        projects: [StudioProject]
    ) -> [FeatureInsightStrip] {
        let store = SettingsStore.shared
        var strips: [FeatureInsightStrip] = []

        // Payment sources
        let creditInsight = PaymentSourceInsightsEngine.generateInsights(transactions: transactions).first
        strips.append(
            FeatureInsightStrip(
                id: "payment_sources",
                title: "Credit & BNPL",
                value: creditInsight?.value ?? (store.paymentSourceTrackingEnabled ? "Tag expenses" : "Off"),
                subtitle: creditInsight?.description ?? "Enable payment tagging in Settings",
                systemIcon: "creditcard.trianglebadge.exclamationmark",
                accentColorName: "orange",
                isFeatureEnabled: store.paymentSourceTrackingEnabled,
                hasData: creditInsight != nil,
                ctaLabel: store.paymentSourceTrackingEnabled ? nil : "Settings → Payment Sources"
            )
        )

        // Dual cash
        let cashInsight = CashDigitalInsightsEngine.generateInsights(transactions: transactions).first
        strips.append(
            FeatureInsightStrip(
                id: "dual_cash",
                title: "Cash Drawer",
                value: store.dualCashDrawerEnabled
                    ? "\(store.primaryLocalCurrency) \(String(format: "%.0f", store.cashLocalBalanceValue))"
                    : "Off",
                subtitle: cashInsight?.description ?? (store.studioEnabled ? "Enable in Studio → Cash & Barter" : "Enable Studio first"),
                systemIcon: "banknote.fill",
                accentColorName: "green",
                isFeatureEnabled: store.studioEnabled && store.dualCashDrawerEnabled,
                hasData: cashInsight != nil,
                ctaLabel: store.studioEnabled ? "Studio → Cash & Barter" : "Studio → Turn on"
            )
        )

        // Barter
        let barterInsight = BarterInsightsEngine.generateInsights(transactions: transactions).first
        strips.append(
            FeatureInsightStrip(
                id: "barter",
                title: "Barter & Trade",
                value: barterInsight?.value ?? "No trades",
                subtitle: barterInsight?.description ?? "Log non-cash exchanges",
                systemIcon: "arrow.left.arrow.right.circle.fill",
                accentColorName: "orange",
                isFeatureEnabled: store.studioEnabled && store.barterLoggerEnabled,
                hasData: barterInsight != nil,
                ctaLabel: store.studioEnabled ? "Studio → Cash & Barter" : "Studio → Turn on"
            )
        )

        // Workspaces
        let workspaceInsight = WorkspaceInsightsEngine.generateInsights(transactions: transactions).first
        let workspaceLabel = HustleWorkspaceFilter.activeWorkspaceLabel() ?? "All workspaces"
        strips.append(
            FeatureInsightStrip(
                id: "workspaces",
                title: "Workspaces",
                value: store.sideHustleMatrixEnabled ? workspaceLabel : "Off",
                subtitle: workspaceInsight?.description ?? "Separate gigs or departments",
                systemIcon: "square.grid.2x2.fill",
                accentColorName: "purple",
                isFeatureEnabled: store.sideHustleMatrixEnabled,
                hasData: workspaceInsight != nil || HustleManager.shared.hustles.count > 1,
                ctaLabel: store.studioEnabled ? "Studio → Workspaces" : "Studio → Turn on"
            )
        )

        // Burnout / creative energy
        strips.append(
            FeatureInsightStrip(
                id: "burnout",
                title: "Creative Energy",
                value: store.burnoutGuardEnabled ? "\(Int(burnout.creativeEnergyPercent))%" : "Off",
                subtitle: store.burnoutGuardEnabled
                    ? "\(String(format: "%.1f", burnout.workHours))h work · \(String(format: "%.1f", burnout.sleepHours))h sleep"
                    : "Track workload & rest",
                systemIcon: "bolt.heart.fill",
                accentColorName: burnout.creativeEnergyPercent > 45 ? "green" : "orange",
                isFeatureEnabled: store.burnoutGuardEnabled,
                hasData: burnout.workHours > 0 || burnout.stressExpenseCount > 0,
                ctaLabel: store.studioEnabled ? "Studio → Workload & Energy" : "Studio → Turn on"
            )
        )

        // Scope radar (Pro)
        let scopeInsight = ScopeCreepInsightsEngine.generateInsights(projects: projects).first
        strips.append(
            FeatureInsightStrip(
                id: "scope_radar",
                title: "Scope Radar",
                value: scopeInsight?.value ?? "Clear",
                subtitle: scopeInsight?.description ?? "Hours & revision guardrails",
                systemIcon: "scope",
                accentColorName: "red",
                isFeatureEnabled: store.studioEnabled && store.studioMode == .pro && store.antiScopeCreepEnabled,
                hasData: scopeInsight != nil,
                ctaLabel: store.studioMode == .pro ? "Studio → Scope Radar" : "Upgrade to Pro"
            )
        )

        return strips
    }
}
