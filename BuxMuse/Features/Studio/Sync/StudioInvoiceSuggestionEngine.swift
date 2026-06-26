//
//  StudioInvoiceSuggestionEngine.swift
//  BuxMuse
//
//  Job ↔ invoice suggestions (Pro projects + Simple jobs). Additive; existing flows unchanged.
//

import Foundation

public enum StudioInvoiceSuggestionReason: String, Codable, Sendable, CaseIterable {
    case billableHours
    case newHoursSinceInvoice
    case projectExpenses
    case jobBalanceDue
    case hourlyLoggedTime
    case agreementLinked

    public func chipLabel(locale: Locale) -> String {
        switch self {
        case .billableHours: return BuxCatalogLabel.string("Billable hours", locale: locale)
        case .newHoursSinceInvoice: return BuxCatalogLabel.string("New hours", locale: locale)
        case .projectExpenses: return BuxCatalogLabel.string("Expenses", locale: locale)
        case .jobBalanceDue: return BuxCatalogLabel.string("Still owed", locale: locale)
        case .hourlyLoggedTime: return BuxCatalogLabel.string("Hours logged", locale: locale)
        case .agreementLinked: return BuxCatalogLabel.string("Agreement", locale: locale)
        }
    }
}

public struct SimpleJobInvoicePick: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let jobId: UUID
    public let jobLabel: String
    public let subtitle: String
    public let amount: Decimal

    public init(jobId: UUID, jobLabel: String, subtitle: String, amount: Decimal) {
        self.id = jobId
        self.jobId = jobId
        self.jobLabel = jobLabel
        self.subtitle = subtitle
        self.amount = amount
    }
}

public struct StudioInvoiceSuggestion: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let amount: Decimal
    public let lineItems: [StudioInvoiceLineItem]
    public let clientId: UUID?
    public let projectId: UUID?
    public let simpleJobId: UUID?
    public let reasons: [StudioInvoiceSuggestionReason]

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        amount: Decimal,
        lineItems: [StudioInvoiceLineItem],
        clientId: UUID? = nil,
        projectId: UUID? = nil,
        simpleJobId: UUID? = nil,
        reasons: [StudioInvoiceSuggestionReason]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.lineItems = lineItems
        self.clientId = clientId
        self.projectId = projectId
        self.simpleJobId = simpleJobId
        self.reasons = reasons
    }
}

public struct SimpleInvoiceSuggestion: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let jobId: UUID
    public let customerName: String
    public let jobDescription: String
    public let amount: Decimal
    public let subtitle: String
    public let reasons: [StudioInvoiceSuggestionReason]

    public init(
        id: UUID = UUID(),
        jobId: UUID,
        customerName: String,
        jobDescription: String,
        amount: Decimal,
        subtitle: String,
        reasons: [StudioInvoiceSuggestionReason]
    ) {
        self.id = id
        self.jobId = jobId
        self.customerName = customerName
        self.jobDescription = jobDescription
        self.amount = amount
        self.subtitle = subtitle
        self.reasons = reasons
    }
}

/// Row in the invoice composer “bill from project” picker for a client.
public struct ClientProjectInvoicePick: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let projectId: UUID
    public let projectName: String
    public let statusLabel: String
    public let subtitle: String
    public let amount: Decimal
    public let lineItems: [StudioInvoiceLineItem]

    public init(
        projectId: UUID,
        projectName: String,
        statusLabel: String,
        subtitle: String,
        amount: Decimal,
        lineItems: [StudioInvoiceLineItem]
    ) {
        self.id = projectId
        self.projectId = projectId
        self.projectName = projectName
        self.statusLabel = statusLabel
        self.subtitle = subtitle
        self.amount = amount
        self.lineItems = lineItems
    }
}

enum StudioInvoiceSuggestionEngine {

    // MARK: - Pro

    static func proSuggestions(
        store: StudioStore,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [StudioInvoiceSuggestion] {
        store.projects.compactMap { projectSuggestion(project: $0, store: store, locale: locale) }
            .sorted { $0.amount > $1.amount }
    }

    /// Completed projects for this client — used when picking a job to populate a manual invoice.
    static func completedProjectPicks(
        for clientId: UUID,
        store: StudioStore,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [ClientProjectInvoicePick] {
        store.projects
            .filter { $0.clientId == clientId && $0.resolvedStatus == .completed }
            .sorted { ($0.endDate ?? $0.startDate) > ($1.endDate ?? $0.startDate) }
            .compactMap { project in
                guard let draft = invoiceDraft(for: project, store: store, locale: locale)
                    ?? fallbackCompletedProjectDraft(project: project, store: store, locale: locale) else {
                    return nil
                }
                return ClientProjectInvoicePick(
                    projectId: project.id,
                    projectName: project.name,
                    statusLabel: project.resolvedStatus.rawValue,
                    subtitle: draft.subtitle,
                    amount: draft.amount,
                    lineItems: draft.lineItems
                )
            }
    }

    static func invoiceDraft(
        for project: StudioProject,
        store: StudioStore,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> StudioInvoiceSuggestion? {
        projectSuggestion(project: project, store: store, locale: locale)
    }

    private static func fallbackCompletedProjectDraft(
        project: StudioProject,
        store: StudioStore,
        locale: Locale
    ) -> StudioInvoiceSuggestion? {
        guard project.resolvedStatus == .completed else { return nil }

        var lineItems: [StudioInvoiceLineItem] = []
        if let fixed = project.fixedFee, fixed > 0 {
            lineItems.append(
                StudioInvoiceLineItem(
                    description: BuxLocalizedString.format(
                        "Project — %@",
                        locale: locale,
                        project.name
                    ),
                    quantity: 1,
                    unitPrice: fixed,
                    category: "Fixed"
                )
            )
        } else {
            let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: store.receipts)
            if let rate = project.hourlyRate, rate > 0, analysis.billableTime > 0 {
                let hours = analysis.billableTime / 3600.0
                lineItems.append(
                    StudioInvoiceLineItem(
                        description: BuxLocalizedString.format(
                            "Billable time — %@",
                            locale: locale,
                            project.name
                        ),
                        quantity: hours,
                        unitPrice: rate,
                        category: "Time"
                    )
                )
            }
        }

        guard !lineItems.isEmpty else { return nil }

        let amount = lineItems.reduce(Decimal(0)) { $0 + Decimal($1.quantity) * $1.unitPrice }
        return StudioInvoiceSuggestion(
            title: project.name,
            subtitle: BuxCatalogLabel.string("Completed project", locale: locale),
            amount: amount,
            lineItems: lineItems,
            clientId: project.clientId,
            projectId: project.id,
            reasons: [.jobBalanceDue]
        )
    }

    private static func projectSuggestion(
        project: StudioProject,
        store: StudioStore,
        locale: Locale
    ) -> StudioInvoiceSuggestion? {
        let agreement = store.agreementDraft(forProjectId: project.id)
        let linkedInvoices = store.invoices.filter { inv in
            inv.projectId == project.id || project.generatedInvoiceIds.contains(inv.id)
        }
        let activeInvoices = linkedInvoices.filter { $0.status != .cancelled }
        let invoicedTotal = activeInvoices
            .filter { $0.status != .draft }
            .reduce(Decimal(0)) { $0 + $1.total }

        let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: store.receipts)
        var reasons: [StudioInvoiceSuggestionReason] = []
        var lineItems: [StudioInvoiceLineItem] = []

        let lastInvoiceDate = activeInvoices.map(\.issueDate).max()
        let newBillableSeconds = billableSeconds(
            in: project,
            since: lastInvoiceDate
        )

        if newBillableSeconds >= 60, let rate = project.hourlyRate, rate > 0, project.fixedFee == nil {
            let hours = newBillableSeconds / 3600.0
            let amount = Decimal(hours) * rate
            if amount > 0 {
                reasons.append(lastInvoiceDate == nil ? .billableHours : .newHoursSinceInvoice)
                lineItems.append(
                    StudioInvoiceLineItem(
                        description: lastInvoiceDate == nil
                            ? BuxLocalizedString.format(
                                "Billable time — %@",
                                locale: locale,
                                project.name
                            )
                            : BuxLocalizedString.format(
                                "Additional time — %@",
                                locale: locale,
                                project.name
                            ),
                        quantity: hours,
                        unitPrice: rate,
                        category: "Time"
                    )
                )
            }
        } else if project.fixedFee != nil, invoicedTotal == 0 {
            reasons.append(.billableHours)
            lineItems.append(
                StudioInvoiceLineItem(
                    description: BuxLocalizedString.format(
                        "Project fee — %@",
                        locale: locale,
                        project.name
                    ),
                    quantity: 1,
                    unitPrice: project.fixedFee!,
                    category: "Fixed"
                )
            )
        }

        let expenseTotal = projectExpenseTotal(project: project, receipts: store.receipts)
        if expenseTotal > 0, !expensesAlreadyOnInvoice(expenseTotal: expenseTotal, invoices: activeInvoices) {
            reasons.append(.projectExpenses)
            lineItems.append(
                StudioInvoiceLineItem(
                    description: BuxLocalizedString.format(
                        "Project expenses — %@",
                        locale: locale,
                        project.name
                    ),
                    quantity: 1,
                    unitPrice: expenseTotal,
                    category: "Expenses"
                )
            )
        }

        if !lineItems.isEmpty {
            StudioAgreementInvoiceLines.applyAgreementContext(
                lineItems: &lineItems,
                project: project,
                agreement: agreement,
                profile: store.profile
            )
        }

        guard !lineItems.isEmpty else { return nil }

        let subtotal = lineItems.reduce(Decimal(0)) { $0 + Decimal($1.quantity) * $1.unitPrice }
        let balanceGap = max(0, analysis.projectedRevenue - invoicedTotal)
        let amount = max(subtotal, balanceGap)
        if amount <= 0 { return nil }

        if agreement != nil, !reasons.contains(.agreementLinked) {
            reasons.append(.agreementLinked)
        }
        var subtitle = reasons.map { $0.chipLabel(locale: locale) }.joined(separator: " · ")
        if let agreement, !agreement.paymentAmountNotes.isEmpty {
            subtitle += " · " + BuxCatalogLabel.string("per agreement", locale: locale)
        }
        return StudioInvoiceSuggestion(
            title: project.name,
            subtitle: subtitle,
            amount: amount,
            lineItems: lineItems,
            clientId: project.clientId,
            projectId: project.id,
            reasons: reasons
        )
    }

    private static func billableSeconds(in project: StudioProject, since date: Date?) -> TimeInterval {
        project.timeEntries
            .filter { entry in
                guard entry.isBillable else { return false }
                guard let date else { return true }
                return entry.endTime > date
            }
            .reduce(0) { $0 + $1.duration }
    }

    private static func projectExpenseTotal(project: StudioProject, receipts: [StudioReceipt]) -> Decimal {
        receipts
            .filter { project.expenseIds.contains($0.id) || $0.linkedProjectId == project.id }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private static func expensesAlreadyOnInvoice(
        expenseTotal: Decimal,
        invoices: [StudioInvoice]
    ) -> Bool {
        let expenseLines = invoices.flatMap(\.lineItems).filter { $0.category == "Expenses" }
        let summed = expenseLines.reduce(Decimal(0)) { $0 + Decimal($1.quantity) * $1.unitPrice }
        return summed >= expenseTotal * Decimal(0.95)
    }

    // MARK: - Simple

    /// Jobs ready to bill for a customer (mirrors Pro completed-project picker).
    static func billableJobPicks(
        forCustomerName name: String,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) -> [SimpleJobInvoicePick] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return simpleSuggestions(store: store, studioStore: studioStore)
            .filter { $0.customerName.caseInsensitiveCompare(trimmed) == .orderedSame }
            .map {
                SimpleJobInvoicePick(
                    jobId: $0.jobId,
                    jobLabel: $0.jobDescription,
                    subtitle: $0.subtitle,
                    amount: $0.amount
                )
            }
    }

    static func simpleSuggestions(
        store: SimpleStudioStore,
        studioStore: StudioStore,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [SimpleInvoiceSuggestion] {
        store.entries
            .filter { $0.kind == .job }
            .compactMap { simpleJobSuggestion(job: $0, store: store, studioStore: studioStore, locale: locale) }
            .sorted { $0.amount > $1.amount }
    }

    private static func simpleJobSuggestion(
        job: SimpleStudioEntry,
        store: SimpleStudioStore,
        studioStore: StudioStore? = nil,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> SimpleInvoiceSuggestion? {
        let agreement = studioStore.flatMap { StudioWorkDealHelpers.agreement(forJob: job, studioStore: $0) }
        let client = studioStore?.clients.first(where: {
            $0.name.caseInsensitiveCompare(job.customerName) == .orderedSame
        })
        let draft = StudioAgreementInvoiceLines.simpleInvoiceDraft(
            job: job,
            agreement: agreement,
            profile: studioStore?.profile ?? StudioProfile(),
            client: client
        )
        let balance = draft.amount > 0 ? draft.amount : job.jobBalanceDue
        guard balance > 0 else { return nil }

        if let linkedId = job.linkedInvoiceId,
           let invoice = store.invoice(id: linkedId),
           invoice.status == .paid {
            return nil
        }

        var reasons: [StudioInvoiceSuggestionReason] = [.jobBalanceDue]
        var subtitle = BuxCatalogLabel.string("Customer still owes you", locale: locale)

        let effectiveRate = StudioAgreementInvoiceLines.simpleHourlyRate(
            job: job,
            agreement: agreement,
            profile: studioStore?.profile ?? StudioProfile()
        )
        if job.resolvedPayStyle == .byTheHour,
           effectiveRate > 0,
           let logged = job.loggedSeconds,
           logged > 0 {
            reasons.append(.hourlyLoggedTime)
            let hours = SimpleStudioTimePayEngine.formattedHours(logged)
            subtitle = BuxLocalizedString.format(
                "%@ logged at %@/hr",
                locale: locale,
                hours,
                "\(effectiveRate)"
            )
        }

        if agreement != nil {
            reasons.append(.agreementLinked)
            subtitle += draft.usedAgreement
                ? " · " + BuxCatalogLabel.string("per agreement", locale: locale)
                : " · " + BuxCatalogLabel.string("agreement on file", locale: locale)
        }

        return SimpleInvoiceSuggestion(
            jobId: job.id,
            customerName: job.customerName,
            jobDescription: draft.jobDescription,
            amount: balance,
            subtitle: subtitle,
            reasons: reasons
        )
    }
}
