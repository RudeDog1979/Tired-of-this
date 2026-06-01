//
//  MoneyMapBuilder.swift
//  BuxMuse
//
//  Builds the interactive Money Map graph from live financial + Studio data.
//

import Foundation
import SwiftUI

public enum MoneyMapDeepLink: String, Equatable {
    case insightsPill
    case studioTab
    case studioSettings
    case subscriptionHub
    case expensesTab
    case paymentSettings
}

public struct MoneyMapTerritoryDetail: Equatable {
    public var explanation: String
    public var metricLines: [(String, String)]
    public var breakdown: [(String, Double)]
    public var sparkline: [Double]
    public var deepLink: MoneyMapDeepLink?
    public var deepLinkLabel: String?

    public init(
        explanation: String,
        metricLines: [(String, String)] = [],
        breakdown: [(String, Double)] = [],
        sparkline: [Double] = [],
        deepLink: MoneyMapDeepLink? = nil,
        deepLinkLabel: String? = nil
    ) {
        self.explanation = explanation
        self.metricLines = metricLines
        self.breakdown = breakdown
        self.sparkline = sparkline
        self.deepLink = deepLink
        self.deepLinkLabel = deepLinkLabel
    }

    public static func == (lhs: MoneyMapTerritoryDetail, rhs: MoneyMapTerritoryDetail) -> Bool {
        lhs.explanation == rhs.explanation
            && lhs.metricLines.elementsEqual(rhs.metricLines) { $0.0 == $1.0 && $0.1 == $1.1 }
            && lhs.breakdown.elementsEqual(rhs.breakdown) { $0.0 == $1.0 && $0.1 == $1.1 }
            && lhs.sparkline == rhs.sparkline
            && lhs.deepLink == rhs.deepLink
            && lhs.deepLinkLabel == rhs.deepLinkLabel
    }
}

public struct MoneyMapNode: Identifiable, Equatable {
    public enum Kind: String, Equatable {
        case hub
        case categories
        case flow
        case workspace
        case cash
        case energy
        case insight
        case studio
        case subscriptions
        case merchants
        case scope
        case barter
        case payments
        case invoices
        case mileage
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let value: String
    public let subtitle: String
    public let weight: Double
    public let accentName: String
    public let systemIcon: String
    public let angle: Double
    public let ring: Int
    public let isProTerritory: Bool
    public let detail: MoneyMapTerritoryDetail

    public var accentColor: Color {
        switch accentName {
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "mint": return Color(red: 46/255, green: 204/255, blue: 113/255)
        default: return .accentColor
        }
    }
}

public struct MoneyMapGraph {
    public var centerTitle: String
    public var centerValue: String
    public var centerSubtitle: String
    public var nodes: [MoneyMapNode]
    public var categoryBreakdown: [(String, Double)]
    public var merchantBreakdown: [(String, Double)]
    public var trendPoints: [Double]
    public var workspaceBreakdown: [(String, Double)]
    public var topInsightTitle: String?
    public var topInsightDetail: String?
    public var topInsight: FinancialInsight?
    public var subscriptionCount: Int
    public var scopeAlertCount: Int
    public var isProEnriched: Bool
    public var proTerritoryCount: Int
}

enum MoneyMapBuilder {
    @MainActor
    static func build(
        snapshot: ExpenseInteractionDisplay,
        transactions: [Transaction],
        insights: [FinancialInsight],
        featureStrips: [FeatureInsightStrip],
        settings: SettingsStore,
        projects: [StudioProject] = [],
        invoices: [StudioInvoice] = [],
        format: (Decimal) -> String
    ) -> MoneyMapGraph {
        let header = snapshot.header
        let summary = snapshot.summary
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let scopedTxs = HustleWorkspaceFilter.filter(transactions) { $0.hustleId }
        let isPro = settings.studioMode == .pro
        let scopedProjects = HustleWorkspaceFilter.filter(projects) { $0.hustleId }
        let scopeInsights = ScopeCreepInsightsEngine.generateInsights(projects: scopedProjects)
        let subs = transactions.filter { $0.isSubscriptionLike && $0.amount.value < 0 }
        let barterTxs = transactions.filter(\.isBarterExchange)
        let workspaceBreakdown = workspaceTotals(scopedTxs, monthStart: monthStart)
        let trendPoints = summary.trendPoints.isEmpty ? header.sparklinePoints : summary.trendPoints

        var nodes: [MoneyMapNode] = []
        var slot = 0
        let maxSlots = isPro ? 14.0 : 9.0

        func place(
            id: String,
            kind: MoneyMapNode.Kind,
            title: String,
            value: String,
            subtitle: String,
            weight: Double,
            accent: String,
            icon: String,
            ring: Int = 1,
            pro: Bool = false,
            detail: MoneyMapTerritoryDetail
        ) {
            let angle = (Double(slot) / maxSlots) * (.pi * 2) - .pi / 2
            slot += 1
            nodes.append(
                MoneyMapNode(
                    id: id,
                    kind: kind,
                    title: title,
                    value: value,
                    subtitle: subtitle,
                    weight: min(max(weight, 0.35), 1.0),
                    accentName: accent,
                    systemIcon: icon,
                    angle: angle,
                    ring: ring,
                    isProTerritory: pro,
                    detail: detail
                )
            )
        }

        if !summary.categoryBreakdown.isEmpty {
            let top = summary.categoryBreakdown.first!
            let total = summary.categoryBreakdown.reduce(0.0) { $0 + $1.1 }
            place(
                id: "categories",
                kind: .categories,
                title: "Categories",
                value: top.0,
                subtitle: "\(summary.categoryBreakdown.count) lanes",
                weight: 0.55 + min(top.1 / max(summary.totalSpent, 1), 0.45),
                accent: "purple",
                icon: "chart.pie.fill",
                detail: MoneyMapTerritoryDetail(
                    explanation: "Where your money went this month — each lane is a spending category ranked by total.",
                    metricLines: [
                        ("Top category", top.0),
                        ("Top share", pctString(top.1, of: total)),
                        ("Categories tracked", "\(summary.categoryBreakdown.count)")
                    ],
                    breakdown: summary.categoryBreakdown,
                    deepLink: .expensesTab,
                    deepLinkLabel: "Open Expenses →"
                )
            )
        }

        if !trendPoints.isEmpty {
            let delta = header.changeVsLastMonth
            place(
                id: "flow",
                kind: .flow,
                title: "Cash flow",
                value: delta >= 0 ? "+\(Int(delta))%" : "\(Int(delta))%",
                subtitle: "vs last month",
                weight: 0.5 + min(abs(delta) / 100, 0.5),
                accent: delta <= 0 ? "green" : "orange",
                icon: "waveform.path.ecg",
                detail: MoneyMapTerritoryDetail(
                    explanation: delta <= 0
                        ? "Spending is cooling compared to last month — a healthier cash-flow lane."
                        : "Spending is running hotter than last month — watch the trend line.",
                    metricLines: [
                        ("This month", format(Decimal(header.totalSpent))),
                        ("Vs last month", delta >= 0 ? "+\(Int(delta))%" : "\(Int(delta))%"),
                        ("Transactions", "\(header.monthlyTransactionCount)")
                    ],
                    sparkline: trendPoints
                )
            )
        }

        if !subs.isEmpty {
            let subTotal = subs.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            var subByName: [String: Double] = [:]
            for tx in subs {
                let name = tx.merchantName.isEmpty ? (tx.notes ?? "Subscription") : tx.merchantName
                subByName[name, default: 0] += abs(NSDecimalNumber(decimal: tx.amount.value).doubleValue)
            }
            let subBreakdown = subByName.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
            place(
                id: "subscriptions",
                kind: .subscriptions,
                title: "Subscriptions",
                value: "\(subs.count)",
                subtitle: "recurring lanes",
                weight: min(0.45 + Double(subs.count) / 20.0, 0.9),
                accent: "orange",
                icon: "repeat.circle.fill",
                pro: isPro,
                detail: MoneyMapTerritoryDetail(
                    explanation: "Recurring charges detected this month — subscriptions are their own territory on your map.",
                    metricLines: [
                        ("Active subs", "\(subs.count)"),
                        ("Monthly total", format(subTotal)),
                        ("Top sub", subBreakdown.first?.0 ?? "—")
                    ],
                    breakdown: subBreakdown,
                    deepLink: .subscriptionHub,
                    deepLinkLabel: "Open Subscription Hub →"
                )
            )
        }

        if !summary.merchantBreakdown.isEmpty, isPro {
            let top = summary.merchantBreakdown.first!
            let total = summary.merchantBreakdown.reduce(0.0) { $0 + $1.1 }
            place(
                id: "merchants",
                kind: .merchants,
                title: "Merchants",
                value: top.0,
                subtitle: "top spend lane",
                weight: 0.6,
                accent: "blue",
                icon: "storefront.fill",
                pro: true,
                detail: MoneyMapTerritoryDetail(
                    explanation: "Pro territory — see which merchants absorb the most spend this month.",
                    metricLines: [
                        ("Top merchant", top.0),
                        ("Share of spend", pctString(top.1, of: total)),
                        ("Merchants tracked", "\(summary.merchantBreakdown.count)")
                    ],
                    breakdown: summary.merchantBreakdown,
                    deepLink: .expensesTab,
                    deepLinkLabel: "Review in Expenses →"
                )
            )
        }

        if settings.sideHustleMatrixEnabled, !workspaceBreakdown.isEmpty {
            place(
                id: "workspace",
                kind: .workspace,
                title: "Workspaces",
                value: workspaceBreakdown[0].0,
                subtitle: "\(workspaceBreakdown.count) territories",
                weight: 0.6,
                accent: "blue",
                icon: "square.grid.2x2.fill",
                detail: MoneyMapTerritoryDetail(
                    explanation: "Side-Hustle Matrix splits spend across gigs, departments, or clients.",
                    metricLines: [
                        ("Leading workspace", workspaceBreakdown[0].0),
                        ("Workspaces active", "\(workspaceBreakdown.count)"),
                        ("Filter", HustleWorkspaceFilter.activeWorkspaceLabel() ?? "All")
                    ],
                    breakdown: workspaceBreakdown,
                    deepLink: .studioSettings,
                    deepLinkLabel: "Studio → Workspaces →"
                )
            )
        }

        if settings.studioEnabled && settings.dualCashDrawerEnabled {
            place(
                id: "cash",
                kind: .cash,
                title: "Cash drawer",
                value: settings.primaryLocalCurrency,
                subtitle: "\(Int(settings.cashLocalBalanceValue)) local",
                weight: 0.55,
                accent: "green",
                icon: "banknote.fill",
                detail: MoneyMapTerritoryDetail(
                    explanation: "Dual Cash Drawer tracks physical local currency alongside your digital ledger.",
                    metricLines: [
                        ("Local (\(settings.primaryLocalCurrency))", String(format: "%.0f", settings.cashLocalBalanceValue)),
                        ("Trading (\(settings.secondaryTradingCurrency))", String(format: "%.0f", settings.cashSecondaryBalanceValue)),
                        ("Status", settings.dualCashDrawerEnabled ? "Active" : "Off")
                    ],
                    deepLink: .studioSettings,
                    deepLinkLabel: "Studio → Cash & Barter →"
                )
            )
        }

        if settings.studioEnabled && settings.barterLoggerEnabled {
            let barterValue = barterTxs.compactMap(\.barterEstimatedValue).reduce(Decimal(0), +)
            var barterBreakdown: [(String, Double)] = []
            for tx in barterTxs.prefix(6) {
                let label = tx.merchantName.isEmpty ? (tx.notes ?? "Trade") : tx.merchantName
                let val = tx.barterEstimatedValue.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
                barterBreakdown.append((label.isEmpty ? "Trade" : label, val))
            }
            place(
                id: "barter",
                kind: .barter,
                title: "Barter",
                value: "\(barterTxs.count)",
                subtitle: "trade exchanges",
                weight: barterTxs.isEmpty ? 0.4 : 0.7,
                accent: "orange",
                icon: "arrow.left.arrow.right.circle.fill",
                pro: isPro,
                detail: MoneyMapTerritoryDetail(
                    explanation: barterTxs.isEmpty
                        ? "Log non-cash trades here — they appear as their own map lane when you record exchanges."
                        : "Non-cash exchanges logged separately from cash spend for your records.",
                    metricLines: [
                        ("Trades logged", "\(barterTxs.count)"),
                        ("Est. value", barterValue > 0 ? format(barterValue) : "Add values when logging"),
                        ("Latest", barterBreakdown.first?.0 ?? "—")
                    ],
                    breakdown: barterBreakdown,
                    deepLink: .studioSettings,
                    deepLinkLabel: "Studio → Cash & Barter →"
                )
            )
        }

        if settings.paymentSourceTrackingEnabled {
            let paymentInsight = PaymentSourceInsightsEngine.generateInsights(transactions: transactions).first
            let tagged = transactions.filter { $0.amount.value < 0 && !($0.paymentMethod?.isEmpty ?? true) }
            var creditTotal = 0.0
            var bnplTotal = 0.0
            for tx in tagged {
                guard let method = tx.paymentMethod else { continue }
                let amount = abs(NSDecimalNumber(decimal: tx.amount.value).doubleValue)
                if PaymentSourceCatalog.isCreditLike(method) || PaymentSourceCatalog.option(matching: method)?.kind == .credit {
                    creditTotal += amount
                } else if PaymentSourceCatalog.option(matching: method)?.kind == .bnpl {
                    bnplTotal += amount
                }
            }
            place(
                id: "payments",
                kind: .payments,
                title: "Credit & BNPL",
                value: paymentInsight?.value ?? "\(tagged.count) tagged",
                subtitle: paymentInsight?.title ?? "payment lanes",
                weight: 0.5,
                accent: "orange",
                icon: "creditcard.trianglebadge.exclamationmark",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: paymentInsight?.description
                        ?? "Tag expenses with payment methods to see credit vs BNPL concentration.",
                    metricLines: [
                        ("Tagged expenses", "\(tagged.count)"),
                        ("Credit volume", format(Decimal(creditTotal))),
                        ("BNPL volume", format(Decimal(bnplTotal)))
                    ],
                    breakdown: [
                        ("Credit & store credit", creditTotal),
                        ("Buy now, pay later", bnplTotal)
                    ].filter { $0.1 > 0 },
                    deepLink: .paymentSettings,
                    deepLinkLabel: "Settings → Payment Sources →"
                )
            )
        }

        if settings.burnoutGuardEnabled {
            let status = BurnoutEngine.shared.currentStatus
            let pct = status.creativeEnergyPercent
            place(
                id: "energy",
                kind: .energy,
                title: "Energy",
                value: "\(Int(pct))%",
                subtitle: "creative fuel",
                weight: pct / 100,
                accent: pct > 45 ? "mint" : "orange",
                icon: "bolt.heart.fill",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: pct > 45
                        ? "Creative energy is holding — workload and rest are in a workable balance."
                        : "Energy is running low — stress expenses and long hours may be draining your fuel.",
                    metricLines: [
                        ("Creative energy", "\(Int(pct))%"),
                        ("Work hours", String(format: "%.1fh", status.workHours)),
                        ("Sleep hours", String(format: "%.1fh", status.sleepHours)),
                        ("Stress expenses", "\(status.stressExpenseCount)")
                    ],
                    sparkline: [status.workHours, status.sleepHours, Double(status.stressExpenseCount)],
                    deepLink: .studioSettings,
                    deepLinkLabel: "Studio → Workload & Energy →"
                )
            )
        }

        if settings.antiScopeCreepEnabled && isPro && !scopeInsights.isEmpty {
            place(
                id: "scope",
                kind: .scope,
                title: "Scope radar",
                value: "\(scopeInsights.count)",
                subtitle: "alerts active",
                weight: 0.85,
                accent: "red",
                icon: "scope",
                ring: 0,
                pro: true,
                detail: MoneyMapTerritoryDetail(
                    explanation: "Pro scope guardrails — projects near or over budgeted hours light up on the map.",
                    metricLines: scopeInsights.prefix(3).map { ($0.value, $0.description) },
                    breakdown: scopeInsights.map { insight in
                        (insight.value, insight.severity == .high ? 1.0 : 0.6)
                    },
                    deepLink: .studioTab,
                    deepLinkLabel: "Open Studio → Scope →"
                )
            )
        }

        if let top = insights.first {
            place(
                id: "insight",
                kind: .insight,
                title: "Top insight",
                value: top.value,
                subtitle: top.title,
                weight: severityWeight(top.severity),
                accent: top.accentColorName,
                icon: top.systemIcon,
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: top.fullExplanation,
                    metricLines: [
                        ("Signal", top.title),
                        ("Impact / mo", InsightMoneyFormat.format(top.impactMonthly)),
                        ("Severity", top.severity.rawValue.capitalized)
                    ],
                    deepLink: .insightsPill,
                    deepLinkLabel: "Open Insights pill →"
                )
            )
        } else if featureStrips.contains(where: \.hasData) {
            let live = featureStrips.filter(\.hasData)
            place(
                id: "insight",
                kind: .insight,
                title: "Signals",
                value: "\(live.count)",
                subtitle: "live strips",
                weight: 0.5,
                accent: "orange",
                icon: "sparkles",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: "Live feature strips are pulsing — each one connects a BuxMuse tool to real data.",
                    metricLines: live.prefix(4).map { ($0.title, $0.value) },
                    deepLink: .insightsPill,
                    deepLinkLabel: "Open Insights pill →"
                )
            )
        }

        if settings.studioEnabled {
            let monthSpend = scopedTxs
                .filter { $0.amount.value < 0 && $0.date >= monthStart }
                .reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            place(
                id: "studio",
                kind: .studio,
                title: "Studio",
                value: format(monthSpend),
                subtitle: HustleWorkspaceFilter.activeWorkspaceLabel() ?? "All workspaces",
                weight: 0.65,
                accent: "purple",
                icon: "briefcase.fill",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: "Studio workspace spend this month — client work, projects, and creative ops.",
                    metricLines: [
                        ("Month spend", format(monthSpend)),
                        ("Active projects", "\(scopedProjects.count)"),
                        ("Clients", "\(Set(scopedProjects.map(\.clientId)).count)"),
                        ("Workspace", HustleWorkspaceFilter.activeWorkspaceLabel() ?? "All")
                    ],
                    breakdown: workspaceBreakdown,
                    deepLink: .studioTab,
                    deepLinkLabel: "Open Studio →"
                )
            )
        }

        if isPro && settings.studioEnabled {
            let openInvoices = invoices.filter { $0.status == .sent || $0.status == .overdue }
            if !openInvoices.isEmpty {
                let outstanding = openInvoices.reduce(Decimal(0)) { $0 + $1.total }
                place(
                    id: "invoices",
                    kind: .invoices,
                    title: "Invoices",
                    value: "\(openInvoices.count)",
                    subtitle: "awaiting payment",
                    weight: 0.7,
                    accent: "green",
                    icon: "doc.text.fill",
                    pro: true,
                    detail: MoneyMapTerritoryDetail(
                        explanation: "Open invoices waiting on client payment — cash still in transit.",
                        metricLines: [
                            ("Outstanding", format(outstanding)),
                            ("Open count", "\(openInvoices.count)"),
                            ("Overdue", "\(openInvoices.filter { $0.status == .overdue }.count)")
                        ],
                        breakdown: openInvoices.prefix(6).map {
                            ($0.invoiceNumber.isEmpty ? "Invoice" : $0.invoiceNumber, NSDecimalNumber(decimal: $0.total).doubleValue)
                        },
                        deepLink: .studioTab,
                        deepLinkLabel: "Studio → Invoices →"
                    )
                )
            }

            if settings.autoLocationForMileage || !projects.isEmpty {
                let mileageProjects = scopedProjects.filter { !$0.timeEntries.isEmpty }.count
                place(
                    id: "mileage",
                    kind: .mileage,
                    title: "Mileage",
                    value: String(format: "%.2f", settings.mileageRatePerUnitValue),
                    subtitle: "rate / unit",
                    weight: 0.45,
                    accent: "blue",
                    icon: "car.fill",
                    pro: true,
                    detail: MoneyMapTerritoryDetail(
                        explanation: "Mileage rate for deductible travel — tied to Studio projects and location logging.",
                        metricLines: [
                            ("Rate / unit", String(format: "%.2f", settings.mileageRatePerUnitValue)),
                            ("Unit", "mile"),
                            ("Projects w/ time", "\(mileageProjects)")
                        ],
                        deepLink: .studioSettings,
                        deepLinkLabel: "Studio → Mileage →"
                    )
                )
            }
        }

        let proCount = nodes.filter(\.isProTerritory).count

        return MoneyMapGraph(
            centerTitle: "Money Map",
            centerValue: format(Decimal(header.totalSpent)),
            centerSubtitle: "\(header.monthlyTransactionCount) moves · \(nodes.count) territories",
            nodes: nodes,
            categoryBreakdown: summary.categoryBreakdown,
            merchantBreakdown: summary.merchantBreakdown,
            trendPoints: trendPoints,
            workspaceBreakdown: workspaceBreakdown,
            topInsightTitle: insights.first?.title,
            topInsightDetail: insights.first?.description,
            topInsight: insights.first,
            subscriptionCount: subs.count,
            scopeAlertCount: scopeInsights.count,
            isProEnriched: isPro,
            proTerritoryCount: proCount
        )
    }

    private static func workspaceTotals(_ scopedTxs: [Transaction], monthStart: Date) -> [(String, Double)] {
        var totals: [String: Double] = [:]
        for tx in scopedTxs where tx.date >= monthStart && tx.amount.value < 0 {
            let label: String
            if let id = tx.hustleId,
               let hustle = HustleManager.shared.hustles.first(where: { $0.id == id }) {
                label = hustle.name
            } else {
                label = "Unassigned"
            }
            totals[label, default: 0] += abs(NSDecimalNumber(decimal: tx.amount.value).doubleValue)
        }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private static func severityWeight(_ severity: InsightSeverity) -> Double {
        switch severity {
        case .high: return 0.95
        case .medium: return 0.75
        case .low: return 0.55
        }
    }

    private static func pctString(_ part: Double, of total: Double) -> String {
        guard total > 0 else { return "—" }
        return "\(Int((part / total) * 100))%"
    }
}
