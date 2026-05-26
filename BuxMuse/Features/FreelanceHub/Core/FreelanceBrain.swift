//
//  FreelanceBrain.swift
//  BuxMuse
//
//  Orchestrates freelance engines into lightweight UI display models.
//

import Foundation

public enum FreelanceBrain {
    public static func makeDisplay(
        from store: FreelanceStore,
        settings: SettingsStore,
        formatter: AppSettingsManager
    ) -> FreelanceHubDisplay {
        guard settings.freelanceEnabled else { return .empty }

        let profile = store.profile
        let taxResult = FreelanceTaxEngine.computeEstimatedTax(
            profile: profile,
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts
        )
        let forecast = FreelanceCashflowEngine.computeForecast(
            invoices: store.invoices,
            receipts: store.receipts,
            estimatedTax: taxResult.estimatedTax
        )
        let deductions = FreelanceDeductionEngine.computeDeductions(
            receipts: store.receipts,
            taxProfile: store.taxProfile
        )

        let paidInvoices = store.invoices.filter { $0.status == .paid }
        let outstandingInvoices = store.invoices.filter { $0.status == .sent || $0.status == .overdue }
        let totalPaid = paidInvoices.reduce(Decimal(0)) { $0 + $1.total }
        let totalOutstanding = outstandingInvoices.reduce(Decimal(0)) { $0 + $1.total }

        let hasData = !store.clients.isEmpty || !store.invoices.isEmpty || !store.receipts.isEmpty || !store.projects.isEmpty
            || !profile.businessName.isEmpty || !profile.displayName.isEmpty

        let hero = FreelanceHeroDisplay(
            businessTitle: profile.businessName.isEmpty ? "Set Up Your Business" : profile.businessName,
            businessSubtitle: profile.businessType.rawValue,
            estimatedTaxFormatted: formatter.format(taxResult.estimatedTax),
            effectiveTaxRatePercent: Int(taxResult.effectiveTaxRate * 100),
            runwayMonthsFormatted: forecast.runwayMonths > 0 ? String(format: "%.1f mo", forecast.runwayMonths) : "—",
            monthlyBurnFormatted: formatter.format(forecast.historicalBurnRate),
            totalPaidFormatted: formatter.format(totalPaid),
            totalOutstandingFormatted: formatter.format(totalOutstanding),
            paidInvoiceCount: paidInvoices.count,
            outstandingInvoiceCount: outstandingInvoices.count,
            timeToMoneyDays: computeTimeToMoneyDays(invoices: store.invoices),
            hasData: hasData
        )

        let invoicesSummary = buildInvoiceSummary(
            invoices: store.invoices,
            clients: store.clients,
            formatter: formatter
        )

        let topClients = buildTopClients(
            clients: store.clients,
            invoices: store.invoices,
            projects: store.projects,
            receipts: store.receipts,
            formatter: formatter
        )

        let taxSummary = buildTaxDisplay(
            result: taxResult,
            taxProfile: store.taxProfile,
            profile: profile,
            formatter: formatter
        )

        let cashflow = FreelanceCashflowDisplay(
            runwayMonthsFormatted: forecast.runwayMonths > 0 ? String(format: "%.1f months", forecast.runwayMonths) : "—",
            survivalIncomeFormatted: formatter.format(forecast.survivalMonthlyIncomeNeeded),
            projectedInflowFormatted: formatter.format(forecast.projectedInflow30Days),
            burnRateFormatted: formatter.format(forecast.historicalBurnRate),
            survivalModeActive: forecast.runwayMonths < 3 && hasData,
            survivalMessage: forecast.runwayMonths < 3 && hasData
                ? "Runway under 3 months — increase inflow or reduce burn."
                : "Cashflow stable based on current records."
        )

        let projectsSummary = buildProjectsSummary(
            projects: store.projects,
            receipts: store.receipts,
            formatter: formatter
        )

        let receiptsSummary = buildReceiptsSummary(
            receipts: store.receipts,
            deductibleTotal: deductions.totalDeductible,
            formatter: formatter
        )

        let deductionDisplays = deductions.opportunities.map { opp in
            FreelanceDeductionDisplay(
                id: opp.id,
                title: opp.title,
                description: opp.description,
                savingsFormatted: opp.estimatedTaxSaving > 0
                    ? formatter.format(opp.estimatedTaxSaving)
                    : "Configure tax rules"
            )
        }

        let alerts = buildAlerts(
            clients: topClients,
            invoices: store.invoices,
            projects: store.projects,
            taxSummary: taxSummary,
            cashflow: cashflow
        )

        return FreelanceHubDisplay(
            hero: hero,
            invoicesSummary: invoicesSummary,
            topClients: topClients,
            taxSummary: taxSummary,
            cashflow: cashflow,
            projectsSummary: projectsSummary,
            receiptsSummary: receiptsSummary,
            deductionOpportunities: deductionDisplays,
            alerts: alerts,
            isEmpty: !hasData
        )
    }

    // MARK: - Builders

    private static func buildInvoiceSummary(
        invoices: [FreelanceInvoice],
        clients: [FreelanceClient],
        formatter: AppSettingsManager
    ) -> FreelanceInvoiceSummaryDisplay {
        let paid = invoices.filter { $0.status == .paid }
        let outstanding = invoices.filter { $0.status == .sent || $0.status == .overdue }
        let nextDue = outstanding.sorted { $0.dueDate < $1.dueDate }.first
        let nextClient = nextDue.flatMap { inv in clients.first(where: { $0.id == inv.clientId })?.name }

        return FreelanceInvoiceSummaryDisplay(
            draftCount: invoices.filter { $0.status == .draft }.count,
            sentCount: invoices.filter { $0.status == .sent }.count,
            paidCount: paid.count,
            overdueCount: invoices.filter { $0.status == .overdue }.count,
            totalOutstandingFormatted: formatter.format(outstanding.reduce(0) { $0 + $1.total }),
            totalPaidFormatted: formatter.format(paid.reduce(0) { $0 + $1.total }),
            nextDueDate: nextDue?.dueDate,
            nextDueClientName: nextClient
        )
    }

    private static func buildTopClients(
        clients: [FreelanceClient],
        invoices: [FreelanceInvoice],
        projects: [FreelanceProject],
        receipts: [FreelanceReceipt],
        formatter: AppSettingsManager
    ) -> [FreelanceClientDisplay] {
        let ranked = clients.map { client -> (FreelanceClientDisplay, Decimal) in
            let analysis = FreelanceClientEngine.analyze(
                client: client,
                invoices: invoices,
                projects: projects,
                receipts: receipts
            )
            let overdueCount = invoices.filter { $0.clientId == client.id && $0.status == .overdue }.count
            let stress = analysis.health.stressScore
            let emotional = Int((analysis.health.profitabilityScore * 0.6) + ((100 - stress) * 0.4))
            let isRedFlag = overdueCount > 0 || client.isFlaggedForStress || analysis.health.overallScore < 45

            let display = FreelanceClientDisplay(
                id: client.id,
                name: client.name,
                lifetimeValueFormatted: formatter.format(analysis.lifetimeValue),
                healthScore: Int(analysis.health.overallScore),
                stressScore: Int(stress),
                emotionalProfitabilityScore: min(100, max(0, emotional)),
                isRedFlag: isRedFlag,
                overdueInvoiceCount: overdueCount
            )
            return (display, analysis.lifetimeValue)
        }
        return ranked.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private static func buildTaxDisplay(
        result: TaxSimulationResult,
        taxProfile: FreelanceTaxProfile,
        profile: FreelanceProfile,
        formatter: AppSettingsManager
    ) -> FreelanceTaxDisplay {
        let needsSetup = taxProfile.incomeTaxRules.isEmpty
        let deadline = taxDeadlineDays(profile: profile, taxProfile: taxProfile)

        return FreelanceTaxDisplay(
            grossIncomeFormatted: formatter.format(result.totalGrossIncome),
            estimatedTaxFormatted: formatter.format(result.estimatedTax),
            netIncomeFormatted: formatter.format(result.netIncome),
            effectiveRatePercent: Int(result.effectiveTaxRate * 100),
            totalDeductionsFormatted: formatter.format(result.totalDeductions),
            taxDeadlineDays: deadline,
            taxDeadlineLabel: deadline.map { "\($0) days until next tax deadline" } ?? "Configure tax profile",
            needsTaxProfileSetup: needsSetup
        )
    }

    private static func buildProjectsSummary(
        projects: [FreelanceProject],
        receipts: [FreelanceReceipt],
        formatter: AppSettingsManager
    ) -> FreelanceProjectsDisplay {
        var overrunCount = 0
        var best: (name: String, profit: Decimal)?

        for project in projects {
            let analysis = FreelanceProjectEngine.analyzeProject(project: project, receipts: receipts)
            if analysis.isOverrunRisk { overrunCount += 1 }
            if best == nil || analysis.projectedProfit > (best?.profit ?? 0) {
                best = (project.name, analysis.projectedProfit)
            }
        }

        return FreelanceProjectsDisplay(
            activeCount: projects.count,
            overrunRiskCount: overrunCount,
            topProjectName: best?.name,
            topProjectProfitFormatted: best.map { formatter.format($0.profit) }
        )
    }

    private static func buildReceiptsSummary(
        receipts: [FreelanceReceipt],
        deductibleTotal: Decimal,
        formatter: AppSettingsManager
    ) -> FreelanceReceiptsDisplay {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let thisMonth = receipts.filter { $0.date >= startOfMonth }

        return FreelanceReceiptsDisplay(
            totalCount: receipts.count,
            deductibleTotalFormatted: formatter.format(deductibleTotal),
            thisMonthCount: thisMonth.count
        )
    }

    private static func buildAlerts(
        clients: [FreelanceClientDisplay],
        invoices: [FreelanceInvoice],
        projects: [FreelanceProject],
        taxSummary: FreelanceTaxDisplay,
        cashflow: FreelanceCashflowDisplay
    ) -> [FreelanceAlertDisplay] {
        var alerts: [FreelanceAlertDisplay] = []

        if taxSummary.needsTaxProfileSetup {
            alerts.append(FreelanceAlertDisplay(
                id: "tax-setup",
                title: "Tax profile incomplete",
                message: "Add income tax brackets in Tax Profile settings for accurate estimates.",
                severity: "medium"
            ))
        }

        if cashflow.survivalModeActive {
            alerts.append(FreelanceAlertDisplay(
                id: "cashflow-survival",
                title: "Cashflow survival mode",
                message: cashflow.survivalMessage,
                severity: "high"
            ))
        }

        for client in clients where client.isRedFlag {
            alerts.append(FreelanceAlertDisplay(
                id: "client-\(client.id.uuidString)",
                title: "Client red flag: \(client.name)",
                message: client.overdueInvoiceCount > 0
                    ? "\(client.overdueInvoiceCount) overdue invoice(s). Health score \(client.healthScore)%."
                    : "High stress impact. Review profitability and terms.",
                severity: "high"
            ))
        }

        let overdue = invoices.filter { $0.status == .overdue }
        if !overdue.isEmpty {
            alerts.append(FreelanceAlertDisplay(
                id: "overdue-invoices",
                title: "\(overdue.count) overdue invoice(s)",
                message: "Follow up on outstanding payments to improve cashflow.",
                severity: "medium"
            ))
        }

        let overrunProjects = projects.filter {
            FreelanceProjectEngine.analyzeProject(project: $0, receipts: []).isOverrunRisk
        }
        if !overrunProjects.isEmpty {
            alerts.append(FreelanceAlertDisplay(
                id: "project-overrun",
                title: "Project overrun risk",
                message: "\(overrunProjects.count) project(s) may exceed time or budget.",
                severity: "medium"
            ))
        }

        if let days = taxSummary.taxDeadlineDays, days <= 30 {
            alerts.append(FreelanceAlertDisplay(
                id: "tax-deadline",
                title: "Tax deadline approaching",
                message: "\(days) days until your next scheduled tax payment.",
                severity: days <= 14 ? "high" : "medium"
            ))
        }

        return alerts
    }

    private static func computeTimeToMoneyDays(invoices: [FreelanceInvoice]) -> Int? {
        let paid = invoices.filter { $0.status == .paid && $0.paymentDate != nil }
        guard !paid.isEmpty else { return nil }

        let intervals = paid.compactMap { inv -> Int? in
            guard let pay = inv.paymentDate else { return nil }
            let days = Calendar.current.dateComponents([.day], from: inv.issueDate, to: pay).day ?? 0
            return max(0, days)
        }
        guard !intervals.isEmpty else { return nil }
        return intervals.reduce(0, +) / intervals.count
    }

    private static func taxDeadlineDays(profile: FreelanceProfile, taxProfile: FreelanceTaxProfile) -> Int? {
        let calendar = Calendar.current
        let now = Date()

        switch taxProfile.paymentSchedule.lowercased() {
        case "monthly":
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
                  let start = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) else { return nil }
            return calendar.dateComponents([.day], from: now, to: start).day
        case "quarterly":
            let month = calendar.component(.month, from: now)
            let quarterEndMonth = ((month - 1) / 3 + 1) * 3
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = quarterEndMonth + 1
            comps.day = 1
            guard let nextQuarter = calendar.date(from: comps) else { return nil }
            return calendar.dateComponents([.day], from: now, to: nextQuarter).day
        default:
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = profile.taxYearStartMonth
            comps.day = 1
            guard var yearStart = calendar.date(from: comps) else { return nil }
            if yearStart <= now {
                yearStart = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? yearStart
            }
            return calendar.dateComponents([.day], from: now, to: yearStart).day
        }
    }
}
