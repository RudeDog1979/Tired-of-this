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
        store: StudioStore
    ) {
        if options.contains(.links) {
            draft.projectId = project.id
            if draft.clientId == nil { draft.clientId = project.clientId }
            if draft.title.isEmpty || draft.title == "Client agreement" {
                draft.title = "\(project.name) agreement"
            }
        }
        if options.contains(.scope), draft.scopeBullets.isEmpty {
            let notes = project.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty { draft.scopeBullets = notes }
        }
        if options.contains(.deliverables), draft.deliverables.isEmpty {
            if project.budgetedHours > 0 {
                draft.deliverables = "Work delivered within agreed scope and revision limits."
            }
        }
        if options.contains(.money), draft.paymentAmountNotes.isEmpty {
            draft.paymentAmountNotes = moneyLine(project: project, store: store)
        }
        if options.contains(.timeline), draft.timelineNotes.isEmpty {
            draft.timelineNotes = timelineLine(project: project)
        }
        if options.contains(.money), draft.paymentTerms.isEmpty {
            let days = store.profile.defaultInvoicePaymentTerms
            if days > 0 { draft.paymentTerms = "Payment due within \(days) days of invoice." }
        }
    }

    @MainActor
    static func applyJob(
        _ job: SimpleStudioEntry,
        options: StudioAgreementPrefillOptions,
        to draft: inout AgreementDraft,
        studioStore: StudioStore,
        simpleStore: SimpleStudioStore
    ) {
        guard job.kind == .job else { return }
        if options.contains(.links) {
            draft.linkedJobEntryId = job.id
            if let customer = simpleStore.customer(named: job.customerName),
               let match = studioStore.clients.first(where: {
                   $0.name.caseInsensitiveCompare(customer.name) == .orderedSame
               }) {
                draft.clientId = match.id
            }
            let label = job.jobLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !label.isEmpty, draft.title.isEmpty || draft.title == "Client agreement" {
                draft.title = "\(label) agreement"
            } else if draft.title.isEmpty || draft.title == "Client agreement" {
                draft.title = "\(job.customerName) agreement"
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
            draft.paymentAmountNotes = moneyLine(job: job, formatter: studioStore.profile.currencyCode)
        }
        if options.contains(.timeline), draft.timelineNotes.isEmpty {
            draft.timelineNotes = timelineLine(job: job)
        }
    }

    private static func moneyLine(project: StudioProject, store: StudioStore) -> String {
        var parts: [String] = []
        if let fixed = project.fixedFee, fixed > 0 {
            parts.append("Fixed fee: \(formatMoney(fixed, code: store.profile.currencyCode))")
        }
        if let rate = project.hourlyRate, rate > 0 {
            parts.append("Hourly: \(formatMoney(rate, code: store.profile.currencyCode)) / hr")
        }
        return parts.joined(separator: "\n")
    }

    private static func moneyLine(job: SimpleStudioEntry, formatter code: String) -> String {
        switch job.resolvedPayStyle {
        case .onePrice:
            if let agreed = job.agreedPrice, agreed > 0 {
                return "Agreed price: \(formatMoney(agreed, code: code))"
            }
        case .byTheHour:
            if let rate = job.hourlyRate, rate > 0 {
                return "Hourly rate: \(formatMoney(rate, code: code)) / hr"
            }
        }
        if job.amount > 0 {
            return "Amount discussed: \(formatMoney(job.amount, code: code))"
        }
        return ""
    }

    private static func timelineLine(project: StudioProject) -> String {
        var parts: [String] = []
        let start = DateFormatter.localizedString(from: project.startDate, dateStyle: .medium, timeStyle: .none)
        parts.append("Start: \(start)")
        if let end = project.endDate {
            let endStr = DateFormatter.localizedString(from: end, dateStyle: .medium, timeStyle: .none)
            parts.append("End: \(endStr)")
        }
        if project.budgetedHours > 0 {
            parts.append("Budget: \(String(format: "%.1f", project.budgetedHours)) hours")
        }
        if project.allowedRevisions > 0 {
            parts.append("Included revisions: \(project.allowedRevisions)")
        }
        return parts.joined(separator: "\n")
    }

    private static func timelineLine(job: SimpleStudioEntry) -> String {
        guard let seconds = job.plannedWorkSeconds, seconds > 0 else { return "" }
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0, m > 0 { return "Planned time on site: \(h) h \(m) min" }
        if h > 0 { return "Planned time on site: \(h) h" }
        return "Planned time on site: \(m) min"
    }

    private static func formatMoney(_ value: Decimal, code: String) -> String {
        let n = NSDecimalNumber(decimal: value)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: n) ?? "\(n)"
    }
}
