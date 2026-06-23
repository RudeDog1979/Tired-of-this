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
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let header = snapshot.header
        let summary = snapshot.summary
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let scopedTxs = HustleWorkspaceFilter.filter(transactions) { $0.hustleId }
        let isPro = settings.studioMode == .pro
        let scopedProjects = HustleWorkspaceFilter.filter(projects) { $0.hustleId }
        let scopeInsights = ScopeCreepInsightsEngine.generateInsights(projects: scopedProjects, locale: locale)
        let subs = transactions.filter { $0.isSubscriptionLike && $0.amount.value < 0 }
        let barterTxs = transactions.filter(\.isBarterExchange)
        let workspaceBreakdown = workspaceTotals(scopedTxs, monthStart: monthStart, locale: locale)
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
                title: MoneyMapL10n.string("Categories", locale: locale),
                value: top.0,
                subtitle: MoneyMapL10n.format("%lld lanes", locale: locale, summary.categoryBreakdown.count),
                weight: 0.55 + min(top.1 / max(summary.totalSpent, 1), 0.45),
                accent: "purple",
                icon: "chart.pie.fill",
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Where your money went this month — each lane is a spending category ranked by total.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("Top category", locale: locale), top.0),
                        (MoneyMapL10n.string("Top share", locale: locale), pctString(top.1, of: total)),
                        (MoneyMapL10n.string("Categories tracked", locale: locale), "\(summary.categoryBreakdown.count)")
                    ],
                    breakdown: summary.categoryBreakdown,
                    deepLink: .expensesTab,
                    deepLinkLabel: MoneyMapL10n.string("Open Expenses →", locale: locale)
                )
            )
        }

        if !trendPoints.isEmpty {
            let delta = summary.changeVsLastMonth
            place(
                id: "flow",
                kind: .flow,
                title: MoneyMapL10n.string("Cash flow", locale: locale),
                value: delta >= 0 ? "+\(Int(delta))%" : "\(Int(delta))%",
                subtitle: MoneyMapL10n.string("vs last month", locale: locale),
                weight: 0.5 + min(abs(delta) / 100, 0.5),
                accent: delta <= 0 ? "green" : "orange",
                icon: "waveform.path.ecg",
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        delta <= 0
                            ? "Spending is cooling compared to last month — a healthier cash-flow lane."
                            : "Spending is running hotter than last month — watch the trend line.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("This month", locale: locale), format(Decimal(summary.totalSpent))),
                        (MoneyMapL10n.string("Vs last month", locale: locale), delta >= 0 ? "+\(Int(delta))%" : "\(Int(delta))%"),
                        (MoneyMapL10n.string("Transactions", locale: locale), "\(header.monthlyTransactionCount)")
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
                title: MoneyMapL10n.string("Subscriptions", locale: locale),
                value: "\(subs.count)",
                subtitle: MoneyMapL10n.string("recurring lanes", locale: locale),
                weight: min(0.45 + Double(subs.count) / 20.0, 0.9),
                accent: "orange",
                icon: "repeat.circle.fill",
                pro: isPro,
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Recurring charges detected this month — subscriptions are their own territory on your map.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("Active subs", locale: locale), "\(subs.count)"),
                        (MoneyMapL10n.string("Monthly total", locale: locale), format(subTotal)),
                        (MoneyMapL10n.string("Top sub", locale: locale), subBreakdown.first?.0 ?? "—")
                    ],
                    breakdown: subBreakdown,
                    deepLink: .subscriptionHub,
                    deepLinkLabel: MoneyMapL10n.string("Open Subscription Hub →", locale: locale)
                )
            )
        }

        if !summary.merchantBreakdown.isEmpty, isPro {
            let top = summary.merchantBreakdown.first!
            let total = summary.merchantBreakdown.reduce(0.0) { $0 + $1.1 }
            place(
                id: "merchants",
                kind: .merchants,
                title: MoneyMapL10n.string("Merchants", locale: locale),
                value: top.0,
                subtitle: MoneyMapL10n.string("top spend lane", locale: locale),
                weight: 0.6,
                accent: "blue",
                icon: "storefront.fill",
                pro: true,
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Pro territory — see which merchants absorb the most spend this month.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("Top merchant", locale: locale), top.0),
                        (MoneyMapL10n.string("Share of spend", locale: locale), pctString(top.1, of: total)),
                        (MoneyMapL10n.string("Merchants tracked", locale: locale), "\(summary.merchantBreakdown.count)")
                    ],
                    breakdown: summary.merchantBreakdown,
                    deepLink: .expensesTab,
                    deepLinkLabel: MoneyMapL10n.string("Review in Expenses →", locale: locale)
                )
            )
        }

        if settings.sideHustleMatrixEnabled, !workspaceBreakdown.isEmpty {
            place(
                id: "workspace",
                kind: .workspace,
                title: MoneyMapL10n.string("Workspaces", locale: locale),
                value: workspaceBreakdown[0].0,
                subtitle: MoneyMapL10n.format("%lld territories", locale: locale, workspaceBreakdown.count),
                weight: 0.6,
                accent: "blue",
                icon: "square.grid.2x2.fill",
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Side-Hustle Matrix splits spend across gigs, departments, or clients.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("Leading workspace", locale: locale), workspaceBreakdown[0].0),
                        (MoneyMapL10n.string("Workspaces active", locale: locale), "\(workspaceBreakdown.count)"),
                        (MoneyMapL10n.string("Filter", locale: locale), HustleWorkspaceFilter.activeWorkspaceLabel() ?? MoneyMapL10n.string("All", locale: locale))
                    ],
                    breakdown: workspaceBreakdown,
                    deepLink: .studioSettings,
                    deepLinkLabel: MoneyMapL10n.string("Studio → Workspaces →", locale: locale)
                )
            )
        }

        if settings.studioEnabled && settings.dualCashDrawerEnabled {
            place(
                id: "cash",
                kind: .cash,
                title: MoneyMapL10n.string("Cash drawer", locale: locale),
                value: settings.primaryLocalCurrency,
                subtitle: MoneyMapL10n.format("%lld local", locale: locale, Int(settings.cashLocalBalanceValue)),
                weight: 0.55,
                accent: "green",
                icon: "banknote.fill",
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Dual Cash Drawer tracks physical local currency alongside your digital ledger.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.format("Local (%@)", locale: locale, settings.primaryLocalCurrency), String(format: "%.0f", settings.cashLocalBalanceValue)),
                        (MoneyMapL10n.format("Trading (%@)", locale: locale, settings.secondaryTradingCurrency), String(format: "%.0f", settings.cashSecondaryBalanceValue)),
                        (MoneyMapL10n.string("Status", locale: locale), settings.dualCashDrawerEnabled ? MoneyMapL10n.string("Active", locale: locale) : MoneyMapL10n.string("Off", locale: locale))
                    ],
                    deepLink: .studioSettings,
                    deepLinkLabel: MoneyMapL10n.string("Studio → Cash & Barter →", locale: locale)
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
                title: MoneyMapL10n.string("Barter", locale: locale),
                value: "\(barterTxs.count)",
                subtitle: MoneyMapL10n.string("trade exchanges", locale: locale),
                weight: barterTxs.isEmpty ? 0.4 : 0.7,
                accent: "orange",
                icon: "arrow.left.arrow.right.circle.fill",
                pro: isPro,
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        barterTxs.isEmpty
                            ? "Log non-cash trades here — they appear as their own map lane when you record exchanges."
                            : "Non-cash exchanges logged separately from cash spend for your records.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("Trades logged", locale: locale), "\(barterTxs.count)"),
                        (MoneyMapL10n.string("Est. value", locale: locale), barterValue > 0 ? format(barterValue) : MoneyMapL10n.string("Add values when logging", locale: locale)),
                        (MoneyMapL10n.string("Latest", locale: locale), barterBreakdown.first?.0 ?? "—")
                    ],
                    breakdown: barterBreakdown,
                    deepLink: .studioSettings,
                    deepLinkLabel: MoneyMapL10n.string("Studio → Cash & Barter →", locale: locale)
                )
            )
        }

        if settings.paymentSourceTrackingEnabled {
            let paymentInsight = PaymentSourceInsightsEngine.generateInsights(transactions: transactions, locale: locale).first
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
                title: MoneyMapL10n.string("Credit & BNPL", locale: locale),
                value: paymentInsight?.localizedValue(locale: locale) ?? MoneyMapL10n.format("%lld tagged", locale: locale, tagged.count),
                subtitle: paymentInsight?.localizedDescription(locale: locale) ?? MoneyMapL10n.string("payment lanes", locale: locale),
                weight: 0.5,
                accent: "orange",
                icon: "creditcard.trianglebadge.exclamationmark",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: paymentInsight?.localizedDescription(locale: locale)
                        ?? MoneyMapL10n.string(
                            "Tag expenses with payment methods to see credit vs BNPL concentration.",
                            locale: locale
                        ),
                    metricLines: [
                        (MoneyMapL10n.string("Tagged expenses", locale: locale), "\(tagged.count)"),
                        (MoneyMapL10n.string("Credit volume", locale: locale), format(Decimal(creditTotal))),
                        (MoneyMapL10n.string("BNPL volume", locale: locale), format(Decimal(bnplTotal)))
                    ],
                    breakdown: [
                        (MoneyMapL10n.string("Credit & store credit", locale: locale), creditTotal),
                        (MoneyMapL10n.string("Buy now, pay later", locale: locale), bnplTotal)
                    ].filter { $0.1 > 0 },
                    deepLink: .paymentSettings,
                    deepLinkLabel: MoneyMapL10n.string("Settings → Payment Sources →", locale: locale)
                )
            )
        }

        if settings.burnoutGuardEnabled {
            let status = BurnoutEngine.shared.currentStatus
            let pct = status.creativeEnergyPercent
            place(
                id: "energy",
                kind: .energy,
                title: MoneyMapL10n.string("Energy", locale: locale),
                value: "\(Int(pct))%",
                subtitle: MoneyMapL10n.string("creative fuel", locale: locale),
                weight: pct / 100,
                accent: pct > 45 ? "mint" : "orange",
                icon: "bolt.heart.fill",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        pct > 45
                            ? "Creative energy is holding — workload and rest are in a workable balance."
                            : "Energy is running low — stress expenses and long hours may be draining your fuel.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("Creative energy", locale: locale), "\(Int(pct))%"),
                        (MoneyMapL10n.string("Work hours", locale: locale), String(format: "%.1fh", status.workHours)),
                        (MoneyMapL10n.string("Sleep hours", locale: locale), String(format: "%.1fh", status.sleepHours)),
                        (MoneyMapL10n.string("Stress expenses", locale: locale), "\(status.stressExpenseCount)")
                    ],
                    sparkline: [status.workHours, status.sleepHours, Double(status.stressExpenseCount)],
                    deepLink: .studioSettings,
                    deepLinkLabel: MoneyMapL10n.string("Studio → Workload & Energy →", locale: locale)
                )
            )
        }

        if settings.antiScopeCreepEnabled && isPro && !scopeInsights.isEmpty {
            place(
                id: "scope",
                kind: .scope,
                title: MoneyMapL10n.string("Scope radar", locale: locale),
                value: "\(scopeInsights.count)",
                subtitle: MoneyMapL10n.string("alerts active", locale: locale),
                weight: 0.85,
                accent: "red",
                icon: "scope",
                ring: 0,
                pro: true,
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Pro scope guardrails — projects near or over budgeted hours light up on the map.",
                        locale: locale
                    ),
                    metricLines: scopeInsights.prefix(3).map { ($0.localizedValue(locale: locale), $0.localizedDescription(locale: locale)) },
                    breakdown: scopeInsights.map { insight in
                        (insight.localizedValue(locale: locale), insight.severity == .high ? 1.0 : 0.6)
                    },
                    deepLink: .studioTab,
                    deepLinkLabel: MoneyMapL10n.string("Open Studio → Scope →", locale: locale)
                )
            )
        }

        if let top = insights.first {
            place(
                id: "insight",
                kind: .insight,
                title: MoneyMapL10n.string("Top insight", locale: locale),
                value: top.localizedValue(locale: locale),
                subtitle: top.localizedTitle(locale: locale),
                weight: severityWeight(top.severity),
                accent: top.accentColorName,
                icon: top.systemIcon,
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: top.localizedFullExplanation(locale: locale),
                    metricLines: [
                        (MoneyMapL10n.string("Signal", locale: locale), top.localizedTitle(locale: locale)),
                        (MoneyMapL10n.string("Impact / mo", locale: locale), InsightMoneyFormat.format(top.impactMonthly)),
                        (MoneyMapL10n.string("Severity", locale: locale), top.severity.localizedDisplayName(locale: locale))
                    ],
                    deepLink: .insightsPill,
                    deepLinkLabel: MoneyMapL10n.string("Open Insights pill →", locale: locale)
                )
            )
        } else if featureStrips.contains(where: \.hasData) {
            let live = featureStrips.filter(\.hasData)
            place(
                id: "insight",
                kind: .insight,
                title: MoneyMapL10n.string("Signals", locale: locale),
                value: "\(live.count)",
                subtitle: MoneyMapL10n.string("live strips", locale: locale),
                weight: 0.5,
                accent: "orange",
                icon: "sparkles",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Live feature strips are pulsing — each one connects a BuxMuse tool to real data.",
                        locale: locale
                    ),
                    metricLines: live.prefix(4).map { ($0.localizedTitle(locale: locale), $0.value) },
                    deepLink: .insightsPill,
                    deepLinkLabel: MoneyMapL10n.string("Open Insights pill →", locale: locale)
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
                title: MoneyMapL10n.string("Studio", locale: locale),
                value: format(monthSpend),
                subtitle: HustleWorkspaceFilter.activeWorkspaceLabel() ?? MoneyMapL10n.string("All workspaces", locale: locale),
                weight: 0.65,
                accent: "purple",
                icon: "briefcase.fill",
                ring: 0,
                detail: MoneyMapTerritoryDetail(
                    explanation: MoneyMapL10n.string(
                        "Studio workspace spend this month — client work, projects, and creative ops.",
                        locale: locale
                    ),
                    metricLines: [
                        (MoneyMapL10n.string("Month spend", locale: locale), format(monthSpend)),
                        (MoneyMapL10n.string("Active projects", locale: locale), "\(scopedProjects.count)"),
                        (MoneyMapL10n.string("Clients", locale: locale), "\(Set(scopedProjects.map(\.clientId)).count)"),
                        (MoneyMapL10n.string("Workspace", locale: locale), HustleWorkspaceFilter.activeWorkspaceLabel() ?? MoneyMapL10n.string("All", locale: locale))
                    ],
                    breakdown: workspaceBreakdown,
                    deepLink: .studioTab,
                    deepLinkLabel: MoneyMapL10n.string("Open Studio →", locale: locale)
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
                    title: MoneyMapL10n.string("Invoices", locale: locale),
                    value: "\(openInvoices.count)",
                    subtitle: MoneyMapL10n.string("awaiting payment", locale: locale),
                    weight: 0.7,
                    accent: "green",
                    icon: "doc.text.fill",
                    pro: true,
                    detail: MoneyMapTerritoryDetail(
                        explanation: MoneyMapL10n.string(
                            "Open invoices waiting on client payment — cash still in transit.",
                            locale: locale
                        ),
                        metricLines: [
                            (MoneyMapL10n.string("Outstanding", locale: locale), format(outstanding)),
                            (MoneyMapL10n.string("Open count", locale: locale), "\(openInvoices.count)"),
                            (MoneyMapL10n.string("Overdue", locale: locale), "\(openInvoices.filter { $0.status == .overdue }.count)")
                        ],
                        breakdown: openInvoices.prefix(6).map {
                            ($0.invoiceNumber.isEmpty ? MoneyMapL10n.string("Invoice", locale: locale) : $0.invoiceNumber, NSDecimalNumber(decimal: $0.total).doubleValue)
                        },
                        deepLink: .studioTab,
                        deepLinkLabel: MoneyMapL10n.string("Studio → Invoices →", locale: locale)
                    )
                )
            }

            if settings.autoLocationForMileage || !projects.isEmpty {
                let mileageProjects = scopedProjects.filter { !$0.timeEntries.isEmpty }.count
                place(
                    id: "mileage",
                    kind: .mileage,
                    title: MoneyMapL10n.string("Mileage", locale: locale),
                    value: String(format: "%.2f", settings.mileageRatePerUnitValue),
                    subtitle: MoneyMapL10n.string("rate / unit", locale: locale),
                    weight: 0.45,
                    accent: "blue",
                    icon: "car.fill",
                    pro: true,
                    detail: MoneyMapTerritoryDetail(
                        explanation: MoneyMapL10n.string(
                            "Mileage rate for deductible travel — tied to Studio projects and location logging.",
                            locale: locale
                        ),
                        metricLines: [
                            (MoneyMapL10n.string("Rate / unit", locale: locale), String(format: "%.2f", settings.mileageRatePerUnitValue)),
                            (MoneyMapL10n.string("Unit", locale: locale), MoneyMapL10n.string("mile", locale: locale)),
                            (MoneyMapL10n.string("Projects w/ time", locale: locale), "\(mileageProjects)")
                        ],
                        deepLink: .studioSettings,
                        deepLinkLabel: MoneyMapL10n.string("Studio → Mileage →", locale: locale)
                    )
                )
            }
        }

        let proCount = nodes.filter(\.isProTerritory).count

        return MoneyMapGraph(
            centerTitle: MoneyMapL10n.string("Money Map", locale: locale),
            centerValue: format(Decimal(summary.totalSpent)),
            centerSubtitle: MoneyMapL10n.format(
                "%lld moves · %lld territories",
                locale: locale,
                header.monthlyTransactionCount,
                nodes.count
            ),
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

    private static func workspaceTotals(_ scopedTxs: [Transaction], monthStart: Date, locale: Locale) -> [(String, Double)] {
        var totals: [String: Double] = [:]
        for tx in scopedTxs where tx.date >= monthStart && tx.amount.value < 0 {
            let label: String
            if let id = tx.hustleId,
               let hustle = HustleManager.shared.hustles.first(where: { $0.id == id }) {
                label = hustle.name
            } else {
                label = MoneyMapL10n.string("Unassigned", locale: locale)
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
