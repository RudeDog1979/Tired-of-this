//
//  FreelanceBrain.swift
//  BuxMuse
//
//  Orchestrates freelance engines into UI snapshots — all calculations live here.
//

import Foundation
import Combine

@MainActor
public final class FreelanceBrain: ObservableObject {
    @Published private(set) var hubDisplay: FreelanceHubDisplay = .empty
    @Published private(set) var taxSandboxDisplay: TaxSandboxDisplay = .empty
    @Published private(set) var cashflowDisplay: FreelanceCashflowDisplay = .empty
    @Published private(set) var deductionsDisplay: FreelanceDeductionsSnapshotDisplay = .empty
    @Published private(set) var incomeTaxDisplay: IncomeTaxDisplay = .empty
    @Published private(set) var quarterlyDisplay: QuarterlyTaxDisplay = .empty
    @Published private(set) var complianceDisplay: ComplianceDisplay = .empty
    @Published private(set) var selfEmployedDashboardDisplay: SelfEmployedDashboardDisplay = .empty
    @Published var taxSandboxParams: TaxSandboxParams = .default

    private let store: FreelanceStore
    private let settings: SettingsStore
    private let appSettings: AppSettingsManager
    private var cancellables = Set<AnyCancellable>()

    init(store: FreelanceStore, settings: SettingsStore, appSettings: AppSettingsManager) {
        self.store = store
        self.settings = settings
        self.appSettings = appSettings
        wireRefreshTriggers()
        refreshAll()
    }

    func refreshAll() {
        hubDisplay = buildHubDisplay()
        refreshTaxSandbox()
        refreshCashflow()
        refreshDeductions()
        refreshIncomeTax()
        refreshQuarterly()
        refreshCompliance()
        refreshSelfEmployedDashboard()
    }

    func refreshIncomeTax() {
        incomeTaxDisplay = buildIncomeTaxDisplay()
    }

    func refreshQuarterly() {
        quarterlyDisplay = buildQuarterlyDisplay()
    }

    func refreshCompliance() {
        complianceDisplay = buildComplianceDisplay()
    }

    func refreshSelfEmployedDashboard() {
        selfEmployedDashboardDisplay = buildSelfEmployedDashboardDisplay()
    }

    func refreshTaxSandbox() {
        taxSandboxDisplay = buildTaxSandboxDisplay()
    }

    func refreshCashflow() {
        cashflowDisplay = buildCashflowDisplay()
    }

    func refreshDeductions() {
        deductionsDisplay = buildDeductionsDisplay()
    }

    func setTaxSandboxParams(_ params: TaxSandboxParams) {
        taxSandboxParams = params
        refreshTaxSandbox()
    }

    // MARK: - Wiring

    private func wireRefreshTriggers() {
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        appSettings.$selectedCurrency
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        appSettings.$selectedCountry
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)
    }

    // MARK: - Hub

    private func buildHubDisplay() -> FreelanceHubDisplay {
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
            estimatedTaxFormatted: appSettings.format(taxResult.estimatedTax),
            effectiveTaxRatePercent: Int(taxResult.effectiveTaxRate * 100),
            runwayMonthsFormatted: forecast.runwayMonths > 0 ? String(format: "%.1f mo", forecast.runwayMonths) : "—",
            monthlyBurnFormatted: appSettings.format(forecast.historicalBurnRate),
            totalPaidFormatted: appSettings.format(totalPaid),
            totalOutstandingFormatted: appSettings.format(totalOutstanding),
            paidInvoiceCount: paidInvoices.count,
            outstandingInvoiceCount: outstandingInvoices.count,
            timeToMoneyDays: computeTimeToMoneyDays(invoices: store.invoices),
            hasData: hasData
        )

        return FreelanceHubDisplay(
            hero: hero,
            invoicesSummary: buildInvoiceSummary(invoices: store.invoices, clients: store.clients),
            topClients: buildTopClients(clients: store.clients, invoices: store.invoices, projects: store.projects, receipts: store.receipts),
            taxSummary: buildTaxDisplay(result: taxResult, taxProfile: store.taxProfile, profile: profile),
            cashflow: buildCashflowDisplay(from: forecast, hasData: hasData),
            projectsSummary: buildProjectsSummary(projects: store.projects, receipts: store.receipts),
            receiptsSummary: buildReceiptsSummary(receipts: store.receipts, deductibleTotal: deductions.totalDeductible),
            deductionOpportunities: mapDeductionOpportunities(deductions.opportunities),
            alerts: buildAlerts(
                clients: buildTopClients(clients: store.clients, invoices: store.invoices, projects: store.projects, receipts: store.receipts),
                invoices: store.invoices,
                projects: store.projects,
                taxSummary: buildTaxDisplay(result: taxResult, taxProfile: store.taxProfile, profile: profile),
                cashflow: buildCashflowDisplay(from: forecast, hasData: hasData)
            ),
            isEmpty: !hasData
        )
    }

    // MARK: - Tax sandbox

    private func buildTaxSandboxDisplay() -> TaxSandboxDisplay {
        let taxProfile = store.taxProfile
        let baseResult = FreelanceTaxEngine.computeEstimatedTax(
            profile: store.profile,
            taxProfile: taxProfile,
            invoices: store.invoices,
            receipts: store.receipts
        )
        let simResult = FreelanceTaxEngine.simulate(
            profile: store.profile,
            taxProfile: store.taxProfile,
            baseResult: baseResult,
            vatToggled: taxSandboxParams.indirectTaxRegistered,
            hypotheticalRateIncrease: Decimal(taxSandboxParams.rateIncrease),
            hypotheticalHoursCount: taxSandboxParams.billableHours,
            newPurchasesAmount: Decimal(taxSandboxParams.newPurchases)
        )

        let countryLabel: String
        if let code = taxProfile.selectedTaxCountry, let preset = TaxPresetLoader.preset(for: code) {
            countryLabel = "\(preset.name) (\(code))"
        } else if taxProfile.isTaxProfileConfigured {
            countryLabel = "Custom profile"
        } else {
            countryLabel = "No tax profile saved yet"
        }

        return TaxSandboxDisplay(
            currencyCode: appSettings.selectedCurrency.id,
            incomeTypeLabel: taxProfile.taxIncomeType.summaryLabel,
            countryLabel: countryLabel,
            primaryRulesPreview: taxProfile.primaryTaxRulesText,
            indirectTaxNotes: taxProfile.effectiveIndirectTax,
            indirectTaxRegistrationLabel: IndirectTaxLabelResolver.registrationLabel(for: taxProfile),
            isProfileConfigured: taxProfile.isTaxProfileConfigured,
            base: formatSandboxResult(baseResult),
            simulated: formatSandboxResult(simResult)
        )
    }

    private func formatSandboxResult(_ result: TaxSimulationResult) -> TaxSandboxResultDisplay {
        TaxSandboxResultDisplay(
            grossIncomeFormatted: appSettings.format(result.totalGrossIncome),
            deductionsFormatted: appSettings.format(result.totalDeductions),
            taxableIncomeFormatted: appSettings.format(result.taxableIncome),
            estimatedTaxFormatted: appSettings.format(result.estimatedTax),
            netIncomeFormatted: appSettings.format(result.netIncome),
            indirectTaxFormatted: appSettings.format(result.estimatedVat),
            effectiveRatePercent: Int(result.effectiveTaxRate * 100)
        )
    }

    // MARK: - Income tax / quarterly / compliance / dashboard

    private func buildIncomeTaxDisplay() -> IncomeTaxDisplay {
        guard settings.freelanceEnabled else { return .empty }
        let breakdown = FreelanceIncomeTaxEngine.compute(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile
        )
        let ratesConfigured = store.taxProfile.estimatedIncomeTaxRatePercent != nil
            || store.taxProfile.estimatedSelfEmployedRatePercent != nil
        return IncomeTaxDisplay(
            totalIncomeFormatted: appSettings.format(breakdown.totalIncome),
            deductibleExpensesFormatted: appSettings.format(breakdown.deductibleExpenses),
            taxableIncomeFormatted: appSettings.format(breakdown.taxableIncome),
            incomeTaxFormatted: appSettings.format(breakdown.incomeTax),
            selfEmployedTaxFormatted: appSettings.format(breakdown.selfEmployedTax),
            indirectTaxNetFormatted: appSettings.format(breakdown.indirectTaxNet),
            totalEstimatedTaxFormatted: appSettings.format(breakdown.totalEstimatedTax),
            effectiveRatePercent: Int(breakdown.effectiveRate * 100),
            ratesConfigured: ratesConfigured
        )
    }

    private func buildQuarterlyDisplay() -> QuarterlyTaxDisplay {
        guard settings.freelanceEnabled else { return .empty }
        let estimate = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile,
            taxYearStartMonth: store.profile.taxYearStartMonth
        )
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let range = "\(formatter.string(from: estimate.periodStart)) – \(formatter.string(from: estimate.periodEnd))"
        let nextLabel: String
        if let next = estimate.nextPaymentDate {
            nextLabel = "Next payment: \(formatter.string(from: next))"
        } else {
            nextLabel = "Configure payment schedule in Tax Profile"
        }
        return QuarterlyTaxDisplay(
            quarterLabel: estimate.quarterLabel,
            periodRangeLabel: range,
            incomeTaxFormatted: appSettings.format(estimate.incomeTax),
            selfEmployedTaxFormatted: appSettings.format(estimate.selfEmployedTax),
            indirectTaxFormatted: appSettings.format(estimate.indirectTaxCollected),
            totalDueFormatted: appSettings.format(estimate.totalDue),
            setAsideFormatted: appSettings.format(estimate.suggestedSetAside),
            nextPaymentLabel: nextLabel,
            breakdown: formatIncomeBreakdown(estimate.breakdown)
        )
    }

    private func formatIncomeBreakdown(_ breakdown: IncomeTaxBreakdown) -> IncomeTaxDisplay {
        let ratesConfigured = store.taxProfile.estimatedIncomeTaxRatePercent != nil
            || store.taxProfile.estimatedSelfEmployedRatePercent != nil
        return IncomeTaxDisplay(
            totalIncomeFormatted: appSettings.format(breakdown.totalIncome),
            deductibleExpensesFormatted: appSettings.format(breakdown.deductibleExpenses),
            taxableIncomeFormatted: appSettings.format(breakdown.taxableIncome),
            incomeTaxFormatted: appSettings.format(breakdown.incomeTax),
            selfEmployedTaxFormatted: appSettings.format(breakdown.selfEmployedTax),
            indirectTaxNetFormatted: appSettings.format(breakdown.indirectTaxNet),
            totalEstimatedTaxFormatted: appSettings.format(breakdown.totalEstimatedTax),
            effectiveRatePercent: Int(breakdown.effectiveRate * 100),
            ratesConfigured: ratesConfigured
        )
    }

    private func buildComplianceDisplay() -> ComplianceDisplay {
        guard settings.freelanceEnabled else { return .empty }
        let quarterly = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile,
            taxYearStartMonth: store.profile.taxYearStartMonth
        )
        let result = ComplianceAssistantEngine.analyze(
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            quarterly: quarterly,
            countryCode: appSettings.selectedCountry.id
        )
        return ComplianceDisplay(
            warnings: result.warnings.map { ComplianceItemDisplay(id: $0.id, question: $0.question, answer: $0.answer, severity: $0.severity) },
            faq: result.faq.map { ComplianceItemDisplay(id: $0.id, question: $0.question, answer: $0.answer, severity: $0.severity) }
        )
    }

    private func buildSelfEmployedDashboardDisplay() -> SelfEmployedDashboardDisplay {
        guard settings.freelanceEnabled else { return .empty }
        let breakdown = FreelanceIncomeTaxEngine.compute(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile
        )
        let quarterly = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile,
            taxYearStartMonth: store.profile.taxYearStartMonth
        )
        let expenses = FreelanceDeductionMath.totalCashflowExpenses(receipts: store.receipts)
        let net = breakdown.totalIncome - breakdown.deductibleExpenses - breakdown.totalEstimatedTax
        let forecast = FreelanceCashflowEngine.computeForecast(
            invoices: store.invoices,
            receipts: store.receipts,
            estimatedTax: breakdown.totalEstimatedTax
        )
        let hasData = !store.invoices.isEmpty || !store.receipts.isEmpty
        return SelfEmployedDashboardDisplay(
            incomeFormatted: appSettings.format(breakdown.totalIncome),
            expensesFormatted: appSettings.format(expenses),
            deductibleFormatted: appSettings.format(breakdown.deductibleExpenses),
            netProfitFormatted: appSettings.format(net),
            estimatedTaxFormatted: appSettings.format(breakdown.totalEstimatedTax),
            quarterlyDueFormatted: appSettings.format(quarterly.totalDue),
            effectiveRatePercent: Int(breakdown.effectiveRate * 100),
            runwayMonthsFormatted: forecast.runwayMonths > 0 ? String(format: "%.1f mo", forecast.runwayMonths) : "—",
            hasData: hasData
        )
    }

    // MARK: - Cashflow

    private func buildCashflowDisplay() -> FreelanceCashflowDisplay {
        let hasData = !store.invoices.isEmpty || !store.receipts.isEmpty
        let taxResult = FreelanceTaxEngine.computeEstimatedTax(
            profile: store.profile,
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts
        )
        let forecast = FreelanceCashflowEngine.computeForecast(
            invoices: store.invoices,
            receipts: store.receipts,
            estimatedTax: taxResult.estimatedTax
        )
        return buildCashflowDisplay(from: forecast, hasData: hasData)
    }

    private func buildCashflowDisplay(from forecast: CashflowForecast, hasData: Bool) -> FreelanceCashflowDisplay {
        FreelanceCashflowDisplay(
            runwayMonthsFormatted: forecast.runwayMonths > 0 ? String(format: "%.1f months", forecast.runwayMonths) : "—",
            survivalIncomeFormatted: appSettings.format(forecast.survivalMonthlyIncomeNeeded),
            projectedInflowFormatted: appSettings.format(forecast.projectedInflow30Days),
            burnRateFormatted: appSettings.format(forecast.historicalBurnRate),
            survivalModeActive: forecast.runwayMonths < 3 && hasData,
            survivalMessage: forecast.runwayMonths < 3 && hasData
                ? "Runway under 3 months — increase inflow or reduce burn."
                : "Cashflow stable based on current records."
        )
    }

    // MARK: - Deductions

    private func buildDeductionsDisplay() -> FreelanceDeductionsSnapshotDisplay {
        let deductions = FreelanceDeductionEngine.computeDeductions(
            receipts: store.receipts,
            taxProfile: store.taxProfile
        )
        return FreelanceDeductionsSnapshotDisplay(
            totalFormatted: appSettings.format(deductions.totalDeductible),
            opportunities: mapDeductionOpportunities(deductions.opportunities)
        )
    }

    private func mapDeductionOpportunities(_ opps: [DeductionOpportunity]) -> [FreelanceDeductionDisplay] {
        opps.map { opp in
            FreelanceDeductionDisplay(
                id: opp.id,
                title: opp.title,
                description: opp.description,
                savingsFormatted: opp.estimatedTaxSaving > 0
                    ? appSettings.format(opp.estimatedTaxSaving)
                    : "Configure tax rules"
            )
        }
    }

    // MARK: - Builders

    private func buildInvoiceSummary(
        invoices: [FreelanceInvoice],
        clients: [FreelanceClient]
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
            totalOutstandingFormatted: appSettings.format(outstanding.reduce(0) { $0 + $1.total }),
            totalPaidFormatted: appSettings.format(paid.reduce(0) { $0 + $1.total }),
            nextDueDate: nextDue?.dueDate,
            nextDueClientName: nextClient
        )
    }

    private func buildTopClients(
        clients: [FreelanceClient],
        invoices: [FreelanceInvoice],
        projects: [FreelanceProject],
        receipts: [FreelanceReceipt]
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
                lifetimeValueFormatted: appSettings.format(analysis.lifetimeValue),
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

    private func buildTaxDisplay(
        result: TaxSimulationResult,
        taxProfile: FreelanceTaxProfile,
        profile: FreelanceProfile
    ) -> FreelanceTaxDisplay {
        let needsSetup = !taxProfile.isTaxProfileConfigured
        let deadline = taxDeadlineDays(profile: profile, taxProfile: taxProfile)

        return FreelanceTaxDisplay(
            grossIncomeFormatted: appSettings.format(result.totalGrossIncome),
            estimatedTaxFormatted: needsSetup ? "—" : appSettings.format(result.estimatedTax),
            netIncomeFormatted: appSettings.format(result.netIncome),
            effectiveRatePercent: needsSetup ? 0 : Int(result.effectiveTaxRate * 100),
            totalDeductionsFormatted: appSettings.format(result.totalDeductions),
            taxDeadlineDays: deadline,
            taxDeadlineLabel: deadline.map { "\($0) days until next tax deadline" } ?? "Configure tax profile",
            needsTaxProfileSetup: needsSetup,
            primaryRulesPreview: taxProfile.primaryTaxRulesText,
            incomeTypeLabel: taxProfile.taxIncomeType.summaryLabel
        )
    }

    private func buildProjectsSummary(
        projects: [FreelanceProject],
        receipts: [FreelanceReceipt]
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
            topProjectProfitFormatted: best.map { appSettings.format($0.profit) }
        )
    }

    private func buildReceiptsSummary(
        receipts: [FreelanceReceipt],
        deductibleTotal: Decimal
    ) -> FreelanceReceiptsDisplay {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let thisMonth = receipts.filter { $0.date >= startOfMonth }

        return FreelanceReceiptsDisplay(
            totalCount: receipts.count,
            deductibleTotalFormatted: appSettings.format(deductibleTotal),
            thisMonthCount: thisMonth.count
        )
    }

    private func buildAlerts(
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
                message: "Choose a country preset or enter your tax rules in Tax Profile.",
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

    private func computeTimeToMoneyDays(invoices: [FreelanceInvoice]) -> Int? {
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

    private func taxDeadlineDays(profile: FreelanceProfile, taxProfile: FreelanceTaxProfile) -> Int? {
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
