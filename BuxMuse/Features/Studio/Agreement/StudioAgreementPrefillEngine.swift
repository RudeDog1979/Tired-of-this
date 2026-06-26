//
//  StudioAgreementPrefillEngine.swift
//  BuxMuse
//

import Foundation

struct StudioAgreementPrefillOptions: OptionSet, Sendable {
    let rawValue: Int

    static let scope = StudioAgreementPrefillOptions(rawValue: 1 << 0)
    static let deliverables = StudioAgreementPrefillOptions(rawValue: 1 << 1)
    static let money = StudioAgreementPrefillOptions(rawValue: 1 << 2)
    static let timeline = StudioAgreementPrefillOptions(rawValue: 1 << 3)
    static let links = StudioAgreementPrefillOptions(rawValue: 1 << 4)
    static let all: StudioAgreementPrefillOptions = [.scope, .deliverables, .money, .timeline, .links]
}

enum StudioAgreementPrefillEngine {

    @MainActor
    static func applyProject(
        _ project: StudioProject,
        options: StudioAgreementPrefillOptions,
        to draft: inout AgreementDraft,
        store: StudioStore,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) {
        let defaultTitle = BuxCatalogLabel.string("Client agreement", locale: locale)
        if options.contains(.links) {
            draft.projectId = project.id
            if draft.clientId == nil { draft.clientId = project.clientId }
            if draft.title.isEmpty || draft.title == defaultTitle {
                draft.title = BuxLocalizedString.format("%@ agreement", locale: locale, project.name)
            }
        }
        if options.contains(.scope), draft.scopeBullets.isEmpty {
            let planned = project.plannedScope.trimmingCharacters(in: .whitespacesAndNewlines)
            if !planned.isEmpty {
                draft.scopeBullets = planned
            } else {
                let notes = project.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notes.isEmpty { draft.scopeBullets = notes }
            }
        }
        if options.contains(.deliverables), draft.deliverables.isEmpty {
            let planned = project.plannedDeliverables.trimmingCharacters(in: .whitespacesAndNewlines)
            if !planned.isEmpty {
                draft.deliverables = planned
            } else if project.budgetedHours > 0 {
                draft.deliverables = BuxCatalogLabel.string(
                    "Work delivered within agreed scope and revision limits.",
                    locale: locale
                )
            }
        }
        if options.contains(.money), draft.paymentAmountNotes.isEmpty {
            draft.paymentAmountNotes = moneyLine(project: project, store: store, locale: locale)
        }
        if options.contains(.timeline), draft.timelineNotes.isEmpty {
            draft.timelineNotes = timelineLine(project: project, locale: locale)
        }
        if options.contains(.money), draft.paymentTerms.isEmpty {
            let days = store.profile.defaultInvoicePaymentTerms
            if days > 0 {
                draft.paymentTerms = BuxLocalizedString.format(
                    "Payment due within %lld days of invoice.",
                    locale: locale,
                    Int64(days)
                )
            }
        }
    }

    @MainActor
    static func applyJob(
        _ job: SimpleStudioEntry,
        options: StudioAgreementPrefillOptions,
        to draft: inout AgreementDraft,
        studioStore: StudioStore,
        simpleStore: SimpleStudioStore,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) {
        guard job.kind == .job else { return }
        let defaultTitle = BuxCatalogLabel.string("Client agreement", locale: locale)
        if options.contains(.links) {
            draft.linkedJobEntryId = job.id
            if let customer = simpleStore.customer(named: job.customerName),
               let match = studioStore.clients.first(where: {
                   $0.name.caseInsensitiveCompare(customer.name) == .orderedSame
               }) {
                draft.clientId = match.id
            }
            let label = job.jobLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !label.isEmpty, draft.title.isEmpty || draft.title == defaultTitle {
                draft.title = BuxLocalizedString.format("%@ agreement", locale: locale, label)
            } else if draft.title.isEmpty || draft.title == defaultTitle {
                draft.title = BuxLocalizedString.format("%@ agreement", locale: locale, job.customerName)
            }
            if draft.signOffName.isEmpty { draft.signOffName = job.customerName }
        }
        if options.contains(.scope), draft.scopeBullets.isEmpty {
            var parts: [String] = []
            if let label = job.jobLabel, !label.isEmpty { parts.append(label) }
            if let note = job.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(note)
            }
            draft.scopeBullets = parts.joined(separator: "\n")
        }
        if options.contains(.money), draft.paymentAmountNotes.isEmpty {
            draft.paymentAmountNotes = moneyLine(
                job: job,
                formatter: studioStore.profile.currencyCode,
                locale: locale
            )
        }
        if options.contains(.timeline), draft.timelineNotes.isEmpty {
            draft.timelineNotes = timelineLine(job: job, locale: locale)
        }
    }

    private static func moneyLine(project: StudioProject, store: StudioStore, locale: Locale) -> String {
        var parts: [String] = []
        if let fixed = project.fixedFee, fixed > 0 {
            parts.append(
                BuxLocalizedString.format(
                    "Fixed fee: %@",
                    locale: locale,
                    formatMoney(fixed, code: store.profile.currencyCode)
                )
            )
        }
        if let rate = project.hourlyRate, rate > 0 {
            parts.append(
                BuxLocalizedString.format(
                    "Hourly: %@ / hr",
                    locale: locale,
                    formatMoney(rate, code: store.profile.currencyCode)
                )
            )
        }
        return parts.joined(separator: "\n")
    }

    private static func moneyLine(job: SimpleStudioEntry, formatter code: String, locale: Locale) -> String {
        switch job.resolvedPayStyle {
        case .onePrice:
            if let agreed = job.agreedPrice, agreed > 0 {
                return BuxLocalizedString.format(
                    "Agreed price: %@",
                    locale: locale,
                    formatMoney(agreed, code: code)
                )
            }
        case .byTheHour:
            if let rate = job.hourlyRate, rate > 0 {
                return BuxLocalizedString.format(
                    "Hourly rate: %@ / hr",
                    locale: locale,
                    formatMoney(rate, code: code)
                )
            }
        }
        if job.amount > 0 {
            return BuxLocalizedString.format(
                "Amount discussed: %@",
                locale: locale,
                formatMoney(job.amount, code: code)
            )
        }
        return ""
    }

    private static func timelineLine(project: StudioProject, locale: Locale) -> String {
        var parts: [String] = []
        let start = BuxDisplayDate.monthDayYear(from: project.startDate, locale: locale)
        parts.append(BuxLocalizedString.format("Start: %@", locale: locale, start))
        if let end = project.endDate {
            let endStr = BuxDisplayDate.monthDayYear(from: end, locale: locale)
            parts.append(BuxLocalizedString.format("End: %@", locale: locale, endStr))
        }
        if project.budgetedHours > 0 {
            parts.append(
                BuxLocalizedString.format(
                    "Budget: %.1f hours",
                    locale: locale,
                    project.budgetedHours
                )
            )
        }
        if project.allowedRevisions > 0 {
            parts.append(
                BuxLocalizedString.format(
                    "Included revisions: %lld",
                    locale: locale,
                    Int64(project.allowedRevisions)
                )
            )
        }
        return parts.joined(separator: "\n")
    }

    private static func timelineLine(job: SimpleStudioEntry, locale: Locale) -> String {
        guard let seconds = job.plannedWorkSeconds, seconds > 0 else { return "" }
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0, m > 0 {
            return BuxLocalizedString.format(
                "Planned time on site: %lld h %lld min",
                locale: locale,
                Int64(h),
                Int64(m)
            )
        }
        if h > 0 {
            return BuxLocalizedString.format(
                "Planned time on site: %lld h",
                locale: locale,
                Int64(h)
            )
        }
        return BuxLocalizedString.format(
            "Planned time on site: %lld min",
            locale: locale,
            Int64(m)
        )
    }

    private static func formatMoney(_ value: Decimal, code: String) -> String {
        let n = NSDecimalNumber(decimal: value)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: n) ?? "\(n)"
    }
}
