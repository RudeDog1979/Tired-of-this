//
//  StudioBrain.swift
//  BuxMuse
//
//  Orchestrates freelance engines into UI snapshots — all calculations live here.
//

import Foundation
import Combine
import SwiftUI

@MainActor
public final class StudioBrain: ObservableObject {
    @Published private(set) var hubDisplay: StudioHubDisplay = .empty
    @Published private(set) var taxSandboxDisplay: TaxSandboxDisplay = .empty
    @Published private(set) var cashflowDisplay: StudioCashflowDisplay = .empty
    @Published private(set) var deductionsDisplay: StudioDeductionsSnapshotDisplay = .empty
    @Published private(set) var incomeTaxDisplay: IncomeTaxDisplay = .empty
    @Published private(set) var quarterlyDisplay: QuarterlyTaxDisplay = .empty
    @Published private(set) var complianceDisplay: ComplianceDisplay = .empty
    @Published private(set) var selfEmployedDashboardDisplay: SelfEmployedDashboardDisplay = .empty
    @Published private(set) var taxStudioDisplay: TaxStudioDisplay = .empty
    @Published var taxSandboxParams: TaxSandboxParams = .default

    let store: StudioStore
    private let settings: SettingsStore
    let appSettings: AppSettingsManager
    private var cancellables = Set<AnyCancellable>()
    private var refreshAllWork: DispatchWorkItem?
    private static let refreshCoalesceInterval: TimeInterval = 0.08

    init(store: StudioStore, settings: SettingsStore, appSettings: AppSettingsManager) {
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
        refreshTaxStudio()
    }

    /// Coalesces burst store/settings updates into a single full refresh pass.
    func scheduleRefreshAll() {
        refreshAllWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshAll()
        }
        refreshAllWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.refreshCoalesceInterval, execute: work)
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

    func refreshHubDisplay() {
        hubDisplay = buildHubDisplay()
    }

    func setTaxSandboxParams(_ params: TaxSandboxParams) {
        taxSandboxParams = params
        refreshTaxSandbox()
    }

    // MARK: - Wiring

    private func wireRefreshTriggers() {
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleRefreshAll() }
            .store(in: &cancellables)

        Publishers.MergeMany(
            settings.$studioEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$studioMode.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$studioPersona.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$mileageRatePerUnitValue.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$autoLocationForMileage.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.scheduleRefreshAll() }
        .store(in: &cancellables)

        appSettings.$selectedCurrency
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleRefreshAll() }
            .store(in: &cancellables)

        appSettings.$selectedCountry
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleRefreshAll() }
            .store(in: &cancellables)

        appSettings.$interfaceLanguage
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleRefreshAll() }
            .store(in: &cancellables)

        HustleManager.shared.$selectedHustleId
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAllWork?.cancel()
                self?.refreshHubDisplay()
            }
            .store(in: &cancellables)
    }

    // MARK: - Hub

    private func buildHubDisplay() -> StudioHubDisplay {
        guard settings.studioEnabled else { return .empty }

        let scopedProjects = HustleWorkspaceFilter.filter(store.projects) { $0.hustleId }
        let scopedInvoices = HustleWorkspaceFilter.filter(store.invoices) { $0.hustleId }
        let mergedClients = HustleWorkspaceFilter.filter(store.clients) { $0.hustleId }
            + store.clients.filter { client in
                guard HustleWorkspaceFilter.isFilteringActive else { return false }
                guard client.hustleId == nil else { return false }
                return scopedInvoices.contains(where: { $0.clientId == client.id })
                    || scopedProjects.contains(where: { $0.clientId == client.id })
            }
        let scopedClients = Dictionary(grouping: mergedClients, by: \.id).compactMap(\.value.first)
        let scopedReceipts = store.receipts.filter { receipt in
            guard HustleWorkspaceFilter.isFilteringActive else { return true }
            if let projectId = receipt.linkedProjectId,
               scopedProjects.contains(where: { $0.id == projectId }) {
                return true
            }
            if let clientId = receipt.linkedClientId,
               scopedClients.contains(where: { $0.id == clientId }) {
                return true
            }
            return receipt.linkedProjectId == nil && receipt.linkedClientId == nil
        }

        let profile = store.profile
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let taxResult = StudioTaxEngine.computeEstimatedTax(
            profile: profile,
            taxProfile: store.taxProfile,
            invoices: scopedInvoices,
            receipts: scopedReceipts,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate
        )
        let forecast = StudioCashflowEngine.computeForecast(
            invoices: scopedInvoices,
            receipts: scopedReceipts,
            estimatedTax: taxResult.estimatedTax
        )
        let deductions = StudioDeductionEngine.computeDeductions(
            receipts: scopedReceipts,
            taxProfile: store.taxProfile,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate,
            locale: appSettings.interfaceLocale
        )

        let paidInvoices = scopedInvoices.filter { $0.status == .paid }
        let outstandingInvoices = scopedInvoices.filter { $0.status == .sent || $0.status == .overdue }
        let totalPaid = paidInvoices.reduce(Decimal(0)) { $0 + $1.total }
        let totalOutstanding = outstandingInvoices.reduce(Decimal(0)) { $0 + $1.total }

        let hasData = !scopedClients.isEmpty || !scopedInvoices.isEmpty || !scopedReceipts.isEmpty || !scopedProjects.isEmpty
            || !profile.businessName.isEmpty || !profile.displayName.isEmpty

        let locale = appSettings.interfaceLocale
        let hero = StudioHeroDisplay(
            businessTitle: profile.businessName.isEmpty
                ? BuxCatalogLabel.string("Set Up Your Business", locale: locale)
                : profile.businessName,
            businessSubtitle: profile.businessType.catalogLabel(locale: locale),
            estimatedTaxFormatted: appSettings.format(taxResult.estimatedTax),
            effectiveTaxRatePercent: Int(taxResult.effectiveTaxRate * 100),
            runwayMonthsFormatted: forecast.runwayMonths > 0
                ? BuxLocalizedString.format("%.1f mo", locale: locale, forecast.runwayMonths)
                : "—",
            monthlyBurnFormatted: appSettings.format(forecast.historicalBurnRate),
            totalPaidFormatted: appSettings.format(totalPaid),
            totalOutstandingFormatted: appSettings.format(totalOutstanding),
            paidInvoiceCount: paidInvoices.count,
            outstandingInvoiceCount: outstandingInvoices.count,
            timeToMoneyDays: computeTimeToMoneyDays(invoices: scopedInvoices),
            hasData: hasData
        )

        return StudioHubDisplay(
            hero: hero,
            invoicesSummary: buildInvoiceSummary(invoices: scopedInvoices, clients: scopedClients),
            topClients: buildTopClients(clients: scopedClients, invoices: scopedInvoices, projects: scopedProjects, receipts: scopedReceipts),
            taxSummary: buildTaxDisplay(result: taxResult, taxProfile: store.taxProfile, profile: profile),
            cashflow: buildCashflowDisplay(from: forecast, hasData: hasData),
            projectsSummary: buildProjectsSummary(projects: scopedProjects, receipts: scopedReceipts),
            receiptsSummary: buildReceiptsSummary(receipts: scopedReceipts, deductibleTotal: deductions.totalDeductible),
            deductionOpportunities: mapDeductionOpportunities(deductions.opportunities),
            alerts: buildAlerts(
                clients: buildTopClients(clients: scopedClients, invoices: scopedInvoices, projects: scopedProjects, receipts: scopedReceipts),
                invoices: scopedInvoices,
                projects: scopedProjects,
                taxSummary: buildTaxDisplay(result: taxResult, taxProfile: store.taxProfile, profile: profile),
                cashflow: buildCashflowDisplay(from: forecast, hasData: hasData)
            ),
            isEmpty: !hasData
        )
    }

    // MARK: - Tax sandbox

    private func buildTaxSandboxDisplay() -> TaxSandboxDisplay {
        let taxProfile = store.taxProfile
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let baseResult = StudioTaxEngine.computeEstimatedTax(
            profile: store.profile,
            taxProfile: taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate
        )
        let simResult = StudioTaxEngine.simulate(
            profile: store.profile,
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate,
            vatToggled: taxSandboxParams.simulateVATInScenario,
            hypotheticalRateIncrease: Decimal(taxSandboxParams.rateIncrease),
            hypotheticalHoursCount: taxSandboxParams.billableHours,
            newPurchasesAmount: Decimal(taxSandboxParams.newPurchases)
        )

        let locale = appSettings.interfaceLocale
        let countryLabel: String
        if let code = taxProfile.selectedTaxCountry, let preset = TaxPresetLoader.preset(for: code) {
            countryLabel = TaxCountryDisplayName.pickerLabel(for: preset, locale: locale)
        } else if taxProfile.isTaxProfileConfigured {
            countryLabel = BuxCatalogLabel.string("Custom profile", locale: locale)
        } else {
            countryLabel = BuxCatalogLabel.string("No tax profile saved yet", locale: locale)
        }

        return TaxSandboxDisplay(
            currencyCode: appSettings.selectedCurrency.id,
            incomeTypeLabel: taxProfile.taxIncomeType.catalogSummaryLabel(locale: locale),
            countryLabel: countryLabel,
            primaryRulesPreview: taxProfile.primaryTaxRulesText,
            indirectTaxNotes: taxProfile.effectiveIndirectTax,
            indirectTaxRegistrationLabel: IndirectTaxLabelResolver.registrationLabel(for: taxProfile, locale: locale),
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
        guard settings.studioEnabled else { return .empty }
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        return IncomeTaxDisplayBuilder.build(
            profile: store.profile,
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate,
            format: { appSettings.format($0) },
            locale: appSettings.interfaceLocale
        )
    }

    private func buildQuarterlyDisplay() -> QuarterlyTaxDisplay {
        guard settings.studioEnabled else { return .empty }
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let estimate = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate,
            taxYearStartMonth: store.profile.taxYearStartMonth
        )
        let locale = appSettings.interfaceLocale
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        let range = "\(formatter.string(from: estimate.periodStart)) – \(formatter.string(from: estimate.periodEnd))"
        let nextLabel: String
        if let next = estimate.nextPaymentDate {
            nextLabel = BuxLocalizedString.format(
                "Next payment: %@",
                locale: locale,
                formatter.string(from: next)
            )
        } else {
            nextLabel = BuxCatalogLabel.string("Configure payment schedule in Tax Profile", locale: locale)
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
            || !store.taxProfile.incomeTaxRules.isEmpty
        let netAfterTax = max(
            0,
            breakdown.totalIncome - breakdown.totalEstimatedTax - breakdown.indirectTaxNet
        )
        return IncomeTaxDisplay(
            totalIncomeFormatted: appSettings.format(breakdown.totalIncome),
            deductibleExpensesFormatted: appSettings.format(breakdown.deductibleExpenses),
            taxableIncomeFormatted: appSettings.format(breakdown.taxableIncome),
            incomeTaxFormatted: appSettings.format(breakdown.incomeTax),
            selfEmployedTaxFormatted: appSettings.format(breakdown.selfEmployedTax),
            indirectTaxNetFormatted: appSettings.format(breakdown.indirectTaxNet),
            totalEstimatedTaxFormatted: appSettings.format(breakdown.totalEstimatedTax + breakdown.indirectTaxNet),
            effectiveRatePercent: Int(breakdown.effectiveRate * 100),
            ratesConfigured: ratesConfigured,
            netAfterTaxFormatted: appSettings.format(netAfterTax),
            marginalRatePercent: nil,
            periodLabel: BuxCatalogLabel.string("Current quarter", locale: appSettings.interfaceLocale),
            coverageTierLabel: TaxComputeCatalogStore.shared
                .coverageTier(for: store.taxProfile.selectedTaxCountry ?? store.profile.countryCode)
                .catalogLabelKey,
            rulesAsOfLabel: nil,
            detailLines: [],
            usesCatalogEngine: false
        )
    }

    private func buildComplianceDisplay() -> ComplianceDisplay {
        guard settings.studioEnabled else { return .empty }
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let quarterly = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate,
            taxYearStartMonth: store.profile.taxYearStartMonth
        )
        let result = ComplianceAssistantEngine.analyze(
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            quarterly: quarterly,
            countryCode: appSettings.selectedCountry.id,
            locale: appSettings.interfaceLocale
        )
        return ComplianceDisplay(
            warnings: result.warnings.map { ComplianceItemDisplay(id: $0.id, question: $0.question, answer: $0.answer, severity: $0.severity) },
            faq: result.faq.map { ComplianceItemDisplay(id: $0.id, question: $0.question, answer: $0.answer, severity: $0.severity) }
        )
    }

    private func buildSelfEmployedDashboardDisplay() -> SelfEmployedDashboardDisplay {
        guard settings.studioEnabled else { return .empty }
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let breakdown = WorldTaxEngine.incomeTaxBreakdown(
            profile: store.profile,
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate
        )
        let quarterly = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: store.invoices,
            receipts: store.receipts,
            taxProfile: store.taxProfile,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate,
            taxYearStartMonth: store.profile.taxYearStartMonth
        )
        let expenses = StudioDeductionMath.totalCashflowExpenses(receipts: store.receipts)
        let net = breakdown.totalIncome - breakdown.deductibleExpenses - breakdown.totalEstimatedTax
        let forecast = StudioCashflowEngine.computeForecast(
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
            runwayMonthsFormatted: forecast.runwayMonths > 0
                ? BuxLocalizedString.format("%.1f mo", locale: appSettings.interfaceLocale, forecast.runwayMonths)
                : "—",
            hasData: hasData
        )
    }

    // MARK: - Cashflow

    private func buildCashflowDisplay() -> StudioCashflowDisplay {
        let hasData = !store.invoices.isEmpty || !store.receipts.isEmpty
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let taxResult = StudioTaxEngine.computeEstimatedTax(
            profile: store.profile,
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate
        )
        let forecast = StudioCashflowEngine.computeForecast(
            invoices: store.invoices,
            receipts: store.receipts,
            estimatedTax: taxResult.estimatedTax
        )
        return buildCashflowDisplay(from: forecast, hasData: hasData)
    }

    private func buildCashflowDisplay(from forecast: CashflowForecast, hasData: Bool) -> StudioCashflowDisplay {
        StudioCashflowDisplay(
            runwayMonthsFormatted: forecast.runwayMonths > 0
                ? BuxLocalizedString.format("%.1f months", locale: appSettings.interfaceLocale, forecast.runwayMonths)
                : "—",
            survivalIncomeFormatted: appSettings.format(forecast.survivalMonthlyIncomeNeeded),
            projectedInflowFormatted: appSettings.format(forecast.projectedInflow30Days),
            burnRateFormatted: appSettings.format(forecast.historicalBurnRate),
            survivalModeActive: forecast.runwayMonths < 3 && hasData,
            survivalMessage: forecast.runwayMonths < 3 && hasData
                ? "Runway under 3 months — increase inflow or reduce burn."
                : "Cashflow stable based on current records.",
            inflowSparklinePoints: buildInflowSparkline(invoices: store.invoices)
        )
    }

    private func buildInflowSparkline(invoices: [StudioInvoice], months: Int = 6) -> [Double] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<months).reversed().map { offset in
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: -offset, to: now) ?? now)),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return 0 }
            let paidInMonth = invoices.filter { inv in
                inv.status == .paid && inv.issueDate >= monthStart && inv.issueDate < monthEnd
            }
            let total = paidInMonth.reduce(Decimal(0)) { $0 + $1.total }
            return Double(truncating: NSDecimalNumber(decimal: total))
        }
    }

    // MARK: - Deductions

    private func buildDeductionsDisplay() -> StudioDeductionsSnapshotDisplay {
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let deductions = StudioDeductionEngine.computeDeductions(
            receipts: store.receipts,
            taxProfile: store.taxProfile,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: mileageRate,
            locale: appSettings.interfaceLocale
        )
        let mileageSummary = MileageBrain.summary(
            entries: store.mileageEntries,
            ratePerUnit: mileageRate,
            formatAmount: { appSettings.format($0) }
        )
        let mileageLine: String? = mileageSummary.businessDistanceTotal > 0
            ? "Mileage: \(mileageSummary.businessDistanceFormatted) → \(mileageSummary.deductionFormatted)"
            : nil
        return StudioDeductionsSnapshotDisplay(
            totalFormatted: appSettings.format(deductions.totalDeductible),
            mileageSummaryFormatted: mileageLine,
            opportunities: mapDeductionOpportunities(deductions.opportunities)
        )
    }

    public func mileageSummaryDisplay() -> MileageSummaryDisplay {
        MileageBrain.summary(
            entries: store.mileageEntries,
            ratePerUnit: SettingsStore.shared.mileageRatePerUnit,
            formatAmount: { appSettings.format($0) }
        )
    }

    private func mapDeductionOpportunities(_ opps: [DeductionOpportunity]) -> [StudioDeductionDisplay] {
        return opps.map { opp in
            StudioDeductionDisplay(
                id: opp.id,
                title: opp.title,
                description: opp.description,
                savingsFormatted: opp.estimatedTaxSaving > 0
                    ? appSettings.format(opp.estimatedTaxSaving)
                    : BuxLocalizedString.string("Configure tax rules", locale: appSettings.interfaceLocale)
            )
        }
    }

    // MARK: - Builders

    private func buildInvoiceSummary(
        invoices: [StudioInvoice],
        clients: [StudioClient]
    ) -> StudioInvoiceSummaryDisplay {
        let paid = invoices.filter { $0.status == .paid }
        let outstanding = invoices.filter { $0.status == .sent || $0.status == .overdue }
        let nextDue = outstanding.sorted { $0.dueDate < $1.dueDate }.first
        let nextClient = nextDue.flatMap { inv in clients.first(where: { $0.id == inv.clientId })?.name }

        return StudioInvoiceSummaryDisplay(
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
        clients: [StudioClient],
        invoices: [StudioInvoice],
        projects: [StudioProject],
        receipts: [StudioReceipt]
    ) -> [StudioClientDisplay] {
        let ranked = clients.map { client -> (StudioClientDisplay, Decimal) in
            let analysis = StudioClientEngine.analyze(
                client: client,
                invoices: invoices,
                projects: projects,
                receipts: receipts
            )
            let overdueCount = invoices.filter { $0.clientId == client.id && $0.status == .overdue }.count
            let stress = analysis.health.stressScore
            let emotional = Int((analysis.health.profitabilityScore * 0.6) + ((100 - stress) * 0.4))
            let isRedFlag = overdueCount > 0 || client.isFlaggedForStress || analysis.health.overallScore < 45

            let display = StudioClientDisplay(
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
        taxProfile: StudioTaxProfile,
        profile: StudioProfile
    ) -> StudioTaxDisplay {
        let needsSetup = !taxProfile.isTaxProfileConfigured
        let deadline = taxDeadlineDays(profile: profile, taxProfile: taxProfile)

        return StudioTaxDisplay(
            grossIncomeFormatted: appSettings.format(result.totalGrossIncome),
            estimatedTaxFormatted: needsSetup ? "—" : appSettings.format(result.estimatedTax),
            netIncomeFormatted: appSettings.format(result.netIncome),
            effectiveRatePercent: needsSetup ? 0 : Int(result.effectiveTaxRate * 100),
            totalDeductionsFormatted: appSettings.format(result.totalDeductions),
            taxDeadlineDays: deadline,
            taxDeadlineLabel: deadline.map {
                BuxLocalizedString.format(
                    "%lld days until next tax deadline",
                    locale: appSettings.interfaceLocale,
                    Int64($0)
                )
            } ?? BuxCatalogLabel.string("Configure tax profile", locale: appSettings.interfaceLocale),
            needsTaxProfileSetup: needsSetup,
            primaryRulesPreview: taxProfile.primaryTaxRulesText,
            incomeTypeLabel: taxProfile.taxIncomeType.catalogSummaryLabel(locale: appSettings.interfaceLocale)
        )
    }

    private func buildProjectsSummary(
        projects: [StudioProject],
        receipts: [StudioReceipt]
    ) -> StudioProjectsDisplay {
        var overrunCount = 0
        var best: (name: String, profit: Decimal)?

        for project in projects {
            let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: receipts)
            if analysis.isOverrunRisk { overrunCount += 1 }
            if best == nil || analysis.projectedProfit > (best?.profit ?? 0) {
                best = (project.name, analysis.projectedProfit)
            }
        }

        return StudioProjectsDisplay(
            activeCount: projects.filter { $0.resolvedStatus != .completed }.count,
            overrunRiskCount: overrunCount,
            topProjectName: best?.name,
            topProjectProfitFormatted: best.map { appSettings.format($0.profit) }
        )
    }

    private func buildReceiptsSummary(
        receipts: [StudioReceipt],
        deductibleTotal: Decimal
    ) -> StudioReceiptsDisplay {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let thisMonth = receipts.filter { $0.date >= startOfMonth }

        return StudioReceiptsDisplay(
            totalCount: receipts.count,
            deductibleTotalFormatted: appSettings.format(deductibleTotal),
            thisMonthCount: thisMonth.count
        )
    }

    private func buildAlerts(
        clients: [StudioClientDisplay],
        invoices: [StudioInvoice],
        projects: [StudioProject],
        taxSummary: StudioTaxDisplay,
        cashflow: StudioCashflowDisplay
    ) -> [StudioAlertDisplay] {
        var alerts: [StudioAlertDisplay] = []
        let locale = appSettings.interfaceLocale

        if taxSummary.needsTaxProfileSetup {
            alerts.append(StudioAlertDisplay(
                id: "tax-setup",
                title: BuxLocalizedString.string("Tax profile incomplete", locale: locale),
                message: BuxLocalizedString.string(
                    "Choose a country preset or enter your tax rules in Tax Profile.",
                    locale: locale
                ),
                severity: "medium"
            ))
        }

        if cashflow.survivalModeActive {
            alerts.append(StudioAlertDisplay(
                id: "cashflow-survival",
                title: BuxLocalizedString.string("Cashflow survival mode", locale: locale),
                message: BuxCatalogLabel.string(cashflow.survivalMessage, locale: locale),
                severity: "high"
            ))
        }

        for client in clients where client.isRedFlag {
            let message: String
            if client.overdueInvoiceCount > 0 {
                message = BuxLocalizedString.format(
                    "%lld overdue invoice(s). Health score %lld%%.",
                    locale: locale,
                    client.overdueInvoiceCount,
                    client.healthScore
                )
            } else {
                message = BuxLocalizedString.string(
                    "High stress impact. Review profitability and terms.",
                    locale: locale
                )
            }
            alerts.append(StudioAlertDisplay(
                id: "client-\(client.id.uuidString)",
                title: BuxLocalizedString.format(
                    "Client red flag: %@",
                    locale: locale,
                    client.name
                ),
                message: message,
                severity: "high"
            ))
        }

        let overdue = invoices.filter { $0.status == .overdue }
        if !overdue.isEmpty {
            alerts.append(StudioAlertDisplay(
                id: "overdue-invoices",
                title: BuxLocalizedString.format(
                    "%lld overdue invoice(s)",
                    locale: locale,
                    overdue.count
                ),
                message: BuxLocalizedString.string(
                    "Follow up on outstanding payments to improve cashflow.",
                    locale: locale
                ),
                severity: "medium"
            ))
        }

        let overrunProjects = projects.filter {
            StudioProjectEngine.analyzeProject(project: $0, receipts: []).isOverrunRisk
        }
        if !overrunProjects.isEmpty {
            alerts.append(StudioAlertDisplay(
                id: "project-overrun",
                title: BuxLocalizedString.string("Project overrun risk", locale: locale),
                message: BuxLocalizedString.format(
                    "%lld project(s) may exceed time or budget.",
                    locale: locale,
                    overrunProjects.count
                ),
                severity: "medium"
            ))
        }

        if let days = taxSummary.taxDeadlineDays, days <= 30 {
            alerts.append(StudioAlertDisplay(
                id: "tax-deadline",
                title: BuxLocalizedString.string("Tax deadline approaching", locale: locale),
                message: BuxLocalizedString.format(
                    "%lld days until your next scheduled tax payment.",
                    locale: locale,
                    days
                ),
                severity: days <= 14 ? "high" : "medium"
            ))
        }

        return alerts
    }

    private func computeTimeToMoneyDays(invoices: [StudioInvoice]) -> Int? {
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

    private func taxDeadlineDays(profile: StudioProfile, taxProfile: StudioTaxProfile) -> Int? {
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

    // MARK: - Tax Studio

    public func refreshTaxStudio() {
        guard settings.studioEnabled else {
            taxStudioDisplay = .empty
            return
        }
        taxStudioDisplay = buildTaxStudioDisplay()
    }

    private func buildTaxStudioDisplay() -> TaxStudioDisplay {
        let presetCode = store.taxProfile.selectedTaxCountry ?? store.profile.countryCode
        let preset = TaxPresetLoader.preset(for: presetCode)
        let locale = appSettings.interfaceLocale
        let ctx = TaxStudioContext(
            profile: store.profile,
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            receipts: store.receipts,
            mileageEntries: store.mileageEntries,
            countryPreset: preset,
            catalogUpdatedAt: TaxManager.shared.catalogUpdatedAt,
            now: Date(),
            locale: locale
        )
        let snapshot = TaxStudioOrchestrator.buildSnapshot(ctx)
        let intel = snapshot.intelligence

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let catalogLabel = ctx.catalogUpdatedAt.map {
            BuxLocalizedString.format("Reference data: %@", locale: locale, $0)
        } ?? BuxCatalogLabel.string("Bundled reference data", locale: locale)

        let lastBannerMonth = UserDefaults.standard.string(forKey: "tax_studio_banner_month")
        let currentMonth = taxStudioMonthKey(from: Date())
        let showBanner = lastBannerMonth != currentMonth

        let qMonth = Calendar.current.component(.month, from: intel.quarterly.periodStart)
        let qYear = Calendar.current.component(.year, from: intel.quarterly.periodStart)
        let quarterSubtitle = BuxLocalizedString.format(
            "Q%lld %lld",
            locale: locale,
            Int64(((qMonth - 1) / 3) + 1),
            Int64(qYear)
        )

        let metrics: [TaxStudioMetricDisplay] = [
            .init(id: "taxable", title: "Taxable income", value: appSettings.format(intel.breakdown.taxableIncome), subtitle: "After deductions"),
            .init(id: "deduct", title: "Deductible expenses", value: appSettings.format(intel.breakdown.deductibleExpenses), subtitle: "Business use"),
            .init(id: "tax", title: "Estimated tax", value: appSettings.format(intel.breakdown.totalEstimatedTax), subtitle: "Income + SE"),
            .init(id: "etr", title: "Effective rate", value: "\(Int(intel.breakdown.effectiveRate * 100))%", subtitle: "On gross income"),
            .init(id: "qdue", title: "Quarterly due", value: appSettings.format(intel.quarterly.totalDue), subtitle: quarterSubtitle),
            .init(id: "vat", title: "VAT/GST net", value: appSettings.format(intel.breakdown.indirectTaxNet), subtitle: store.taxProfile.vatRegistered ? "Collected − paid" : "Not registered"),
            .init(
                id: "runway",
                title: "Runway after tax",
                value: BuxLocalizedString.format(
                    "%.1f mo",
                    locale: locale,
                    snapshot.forecast.projectedRunwayAfterTaxMonths
                ),
                subtitle: "Projected"
            ),
            .init(
                id: "health",
                title: "Tax health",
                value: "\(snapshot.health.score)",
                subtitle: snapshot.health.band == .green ? "Low" : (snapshot.health.band == .yellow ? "Medium" : "Elevated")
            )
        ]

        let forecastRows: [TaxStudioMetricDisplay] = [
            .init(id: "finc", title: "Projected taxable income", value: appSettings.format(snapshot.forecast.projectedTaxableIncome), subtitle: "12 months"),
            .init(id: "ftax", title: "Projected tax owed", value: appSettings.format(snapshot.forecast.projectedTaxOwed), subtitle: "At current rates"),
            .init(id: "fq", title: "Projected quarterly", value: appSettings.format(snapshot.forecast.projectedQuarterlyPayment), subtitle: "Estimate"),
            .init(id: "fetr", title: "Projected ETR", value: "\(Int(snapshot.forecast.projectedEffectiveRate * 100))%", subtitle: "Effective tax rate"),
            .init(id: "fvel", title: "Income velocity", value: appSettings.format(snapshot.forecast.monthlyIncomeVelocity), subtitle: "Per month"),
            .init(id: "fexp", title: "Expense velocity", value: appSettings.format(snapshot.forecast.monthlyExpenseVelocity), subtitle: "Per month")
        ]

        let sortedTimeline = snapshot.timeline.sorted { $0.date < $1.date }
        let nextHighlightID = sortedTimeline.first(where: { $0.date >= ctx.now })?.id
            ?? sortedTimeline.first?.id

        let healthDisplay = TaxStudioHealthDisplay(
            score: snapshot.health.score,
            band: snapshot.health.band,
            riskLevel: snapshot.health.riskLevel,
            scoreColorName: taxStudioColorName(for: snapshot.health.band),
            factors: snapshot.health.factors.map {
                TaxStudioHealthFactorDisplay(
                    id: $0.id,
                    title: $0.title,
                    valueLabel: $0.valueLabel,
                    progress: $0.progress
                )
            },
            recommendations: snapshot.health.recommendations.map {
                TaxStudioCoachCardDisplay(
                    id: $0.id,
                    title: $0.title,
                    body: $0.detail,
                    category: BuxCatalogLabel.string("Recommendation", locale: locale)
                )
            }
        )

        let countryLabel: String
        if let preset {
            countryLabel = TaxCountryDisplayName.pickerLabel(for: preset, locale: locale)
        } else if store.taxProfile.isTaxProfileConfigured {
            countryLabel = BuxCatalogLabel.string("Custom profile", locale: locale)
        } else {
            countryLabel = BuxCatalogLabel.string("No preset", locale: locale)
        }

        let hero = TaxStudioHeroDisplay(
            estimatedTax: appSettings.format(intel.breakdown.totalEstimatedTax),
            effectiveRate: "\(Int(intel.breakdown.effectiveRate * 100))%",
            quarterlyDue: appSettings.format(intel.quarterly.totalDue),
            quarterLabel: quarterSubtitle,
            runway: BuxLocalizedString.format(
                "%.1f mo",
                locale: locale,
                snapshot.forecast.projectedRunwayAfterTaxMonths
            ),
            vatSummary: appSettings.format(intel.breakdown.indirectTaxNet),
            countryLabel: countryLabel,
            healthScore: snapshot.health.score,
            healthBand: snapshot.health.band,
            healthRiskLevel: snapshot.health.riskLevel
        )

        let sparkline = TaxStudioChartEngine.taxPressureSparkline(
            invoices: store.invoices,
            receipts: store.receipts,
            mileageEntries: store.mileageEntries,
            mileageRatePerUnit: SettingsStore.shared.mileageRatePerUnit,
            catalogRules: store.taxProfile.deductionCategories,
            effectiveRate: intel.breakdown.effectiveRate,
            now: ctx.now
        )
        let sparklineTotal = sparkline.reduce(0, +)
        let sparklineLabel = appSettings.format(Decimal(sparklineTotal))
        let forecastBars = TaxStudioChartEngine.forecastMonthlyBars(
            projectedAnnualTax: snapshot.forecast.projectedTaxOwed,
            locale: locale,
            now: ctx.now
        )

        return TaxStudioDisplay(
            catalogUpdatedLabel: catalogLabel,
            showMonthlyBanner: showBanner,
            hero: hero,
            metrics: metrics,
            health: healthDisplay,
            autopilot: snapshot.autopilot.map {
                TaxStudioAutopilotDisplay(
                    id: $0.id,
                    message: $0.message,
                    icon: $0.icon,
                    tone: taxStudioAutopilotTone(id: $0.id)
                )
            },
            coachCards: snapshot.coach.map {
                TaxStudioCoachCardDisplay(id: $0.id, title: $0.title, body: $0.body, category: $0.category)
            },
            timeline: sortedTimeline.map { event in
                TaxStudioTimelineEventDisplay(
                    id: event.id,
                    date: event.date,
                    dateLabel: formatter.string(from: event.date),
                    title: event.title,
                    subtitle: event.subtitle,
                    severity: event.severity,
                    accent: taxStudioTimelineColor(event.severity),
                    isNextHighlight: event.id == nextHighlightID
                )
            },
            sanity: snapshot.sanity.warnings.map {
                TaxStudioSanityDisplay(id: $0.id, title: $0.title, detail: $0.detail, suggestion: $0.suggestion)
            },
            forecastRows: forecastRows,
            taxPressureSparkline: sparkline,
            taxPressureSparklineLabel: sparklineLabel,
            forecastMonthlyBars: forecastBars,
            bracketLabel: intel.bracketLabel,
            thresholdWarnings: intel.thresholdWarnings,
            incomeTaxDisplay: incomeTaxDisplay,
            quarterlyDisplay: quarterlyDisplay
        )
    }

    private func taxStudioAutopilotTone(id: String) -> TaxStudioInsightTone {
        switch id {
        case "setaside", "dedweek", "qtrack":
            return .positive
        case "trend", "vateta", "runway", "health":
            return .warning
        default:
            return .info
        }
    }

    private func taxStudioColorName(for band: TaxHealthBand) -> String {
        switch band {
        case .green: return "green"
        case .yellow: return "yellow"
        case .red: return "red"
        }
    }

    private func taxStudioTimelineColor(_ severity: TaxTimelineSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func taxStudioMonthKey(from date: Date) -> String {
        let c = Calendar.current
        return "\(c.component(.year, from: date))-\(c.component(.month, from: date))"
    }
}
