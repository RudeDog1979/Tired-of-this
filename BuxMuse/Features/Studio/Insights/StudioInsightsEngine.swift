//
//  StudioInsightsEngine.swift
//  BuxMuse
//
//  Studio-specific profit & rate insights (on-device).
//

import Foundation

public struct StudioInsightRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    public let subtitle: String
    public let systemImage: String

    public init(
        id: String,
        title: String,
        value: String,
        subtitle: String,
        systemImage: String
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

public struct StudioInsightsSnapshot: Equatable, Sendable {
    public var headline: String
    public var metrics: [StudioInsightRow]
    public var rateOptimizerTip: String?
    public var scopeAlerts: Int
    public var timeLeakageHours: Double

    public static let empty = StudioInsightsSnapshot(
        headline: "Add projects or jobs to see Studio insights.",
        metrics: [],
        rateOptimizerTip: nil,
        scopeAlerts: 0,
        timeLeakageHours: 0
    )
}

public enum StudioInsightsEngine {

    public static func build(
        projects: [StudioProject],
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        simpleEntries: [SimpleStudioEntry],
        profile: StudioProfile,
        locale: Locale,
        currencyFormat: (Decimal) -> String
    ) -> StudioInsightsSnapshot {
        var metrics: [StudioInsightRow] = []
        var scopeAlerts = 0
        var leakageHours = 0.0

        let paidInvoices = invoices.filter { $0.status == .paid }
        let totalRevenue = paidInvoices.reduce(Decimal(0)) { $0 + $1.total }
        let projectCosts = receipts
            .filter { $0.linkedProjectId != nil }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let profit = totalRevenue - projectCosts

        if totalRevenue > 0 {
            metrics.append(.init(
                id: "profit",
                title: BuxCatalogLabel.string("Studio profit", locale: locale),
                value: currencyFormat(profit),
                subtitle: BuxCatalogLabel.string("Paid invoices minus linked project expenses", locale: locale),
                systemImage: "chart.line.uptrend.xyaxis"
            ))
        }

        let billableSeconds = projects.flatMap(\.timeEntries).filter(\.isBillable).reduce(0.0) { $0 + $1.duration }
        let totalSeconds = projects.flatMap(\.timeEntries).reduce(0.0) { $0 + $1.duration }
        let billableHours = billableSeconds / 3600.0
        leakageHours = max(0, (totalSeconds - billableSeconds) / 3600.0)

        if billableHours > 0, totalRevenue > 0 {
            let perHour = totalRevenue / Decimal(billableHours)
            metrics.append(.init(
                id: "per-hour",
                title: BuxCatalogLabel.string("Profit per hour", locale: locale),
                value: currencyFormat(perHour),
                subtitle: BuxCatalogLabel.string("Across logged billable project time", locale: locale),
                systemImage: "clock.badge.checkmark"
            ))
        }

        let jobs = simpleEntries.filter { $0.kind == .job }
        let jobRevenue = jobs
            .filter { $0.paymentStatus == .paid }
            .reduce(Decimal(0)) { partial, job in
                partial + (job.amount > 0 ? job.amount : job.jobBalanceDue)
            }
        if !jobs.isEmpty {
            metrics.append(.init(
                id: "per-job",
                title: BuxCatalogLabel.string("Simple job revenue", locale: locale),
                value: currencyFormat(jobRevenue),
                subtitle: BuxLocalizedString.format(
                    "%lld job(s) tracked",
                    locale: locale,
                    Int64(jobs.count)
                ),
                systemImage: "briefcase.fill"
            ))
        }

        var clientProfit: [UUID: Decimal] = [:]
        for inv in paidInvoices {
            clientProfit[inv.clientId, default: 0] += inv.total
        }
        if let top = clientProfit.max(by: { $0.value < $1.value }) {
            metrics.append(.init(
                id: "top-client",
                title: BuxCatalogLabel.string("Top client (paid)", locale: locale),
                value: currencyFormat(top.value),
                subtitle: BuxCatalogLabel.string("Highest paid invoice total for one client", locale: locale),
                systemImage: "person.crop.circle.badge.checkmark"
            ))
        }

        let fixedCount = projects.filter { $0.isFixedPriceProject }.count
        let hourlyCount = projects.count - fixedCount
        if projects.count > 0 {
            metrics.append(.init(
                id: "mix",
                title: BuxCatalogLabel.string("Project mix", locale: locale),
                value: BuxLocalizedString.format(
                    "%lld hourly · %lld fixed",
                    locale: locale,
                    Int64(hourlyCount),
                    Int64(fixedCount)
                ),
                subtitle: BuxCatalogLabel.string("Active portfolio shape", locale: locale),
                systemImage: "square.grid.2x2"
            ))
        }

        for project in projects {
            let snap = StudioProjectPlannerEngine.snapshot(
                project: project,
                receipts: receipts,
                agreement: nil,
                profile: profile,
                locale: locale
            )
            scopeAlerts += snap.alerts.filter { $0.id.contains("scope") }.count
        }

        var rateTip: String?
        if let defaultRate = profile.defaultHourlyRate, defaultRate > 0 {
            let lowProjects = projects.filter { project in
                let a = StudioProjectEngine.analyzeProject(project: project, receipts: receipts)
                return a.effectiveHourlyRate > 0 && a.effectiveHourlyRate < defaultRate * Decimal(0.9)
            }
            if !lowProjects.isEmpty {
                rateTip = BuxLocalizedString.format(
                    "Raise rates on %lld project(s) — effective hourly is below your %@/hr default.",
                    locale: locale,
                    Int64(lowProjects.count),
                    "\(defaultRate)"
                )
            } else if leakageHours >= 3 {
                rateTip = BuxLocalizedString.format(
                    "You logged %.1fh non-billable — convert admin time or exclude it from client work.",
                    locale: locale,
                    leakageHours
                )
            }
        }

        let headline: String = {
            if metrics.isEmpty {
                return BuxCatalogLabel.string("Add projects or jobs to see Studio insights.", locale: locale)
            }
            if profit > 0 {
                return BuxCatalogLabel.string("Studio is profitable on recorded paid work.", locale: locale)
            }
            return BuxCatalogLabel.string("Track paid invoices and expenses for profit insights.", locale: locale)
        }()

        return StudioInsightsSnapshot(
            headline: headline,
            metrics: metrics,
            rateOptimizerTip: rateTip,
            scopeAlerts: scopeAlerts,
            timeLeakageHours: leakageHours
        )
    }
}
