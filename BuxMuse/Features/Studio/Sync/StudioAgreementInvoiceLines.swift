//
//  StudioAgreementInvoiceLines.swift
//  BuxMuse
//
//  Applies agreement rates, deliverables, and payment terms to invoice drafts.
//

import Foundation

enum StudioAgreementInvoiceLines {

    /// Adjusts suggested line items using linked agreement + project context.
    static func applyAgreementContext(
        lineItems: inout [StudioInvoiceLineItem],
        project: StudioProject,
        agreement: AgreementDraft?,
        profile: StudioProfile
    ) {
        guard let agreement else { return }

        let agreementRate = hourlyRate(from: agreement, project: project, profile: profile)
        if let agreementRate, agreementRate > 0 {
            for index in lineItems.indices {
                var item = lineItems[index]
                guard item.category == "Time" || item.description.lowercased().contains("time") else { continue }
                if item.unitPrice < agreementRate {
                    item.unitPrice = agreementRate
                    if !agreement.deliverables.isEmpty, item.description.contains("—") {
                        let base = item.description.components(separatedBy: "—").first?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? item.description
                        item.description = "\(base) — per agreement"
                    }
                    lineItems[index] = item
                }
            }
        }

        if lineItems.isEmpty, let fixed = project.fixedFee, fixed > 0 {
            let label = agreement.deliverables.isEmpty
                ? "Project — \(project.name)"
                : "Deliverables — \(project.name)"
            lineItems.append(
                StudioInvoiceLineItem(
                    description: label,
                    quantity: 1,
                    unitPrice: fixed,
                    category: "Fixed"
                )
            )
        }
    }

    static func paymentTermsDays(
        agreement: AgreementDraft?,
        profile: StudioProfile,
        client: StudioClient?
    ) -> Int {
        if let agreement, let days = parsePaymentDays(from: agreement.paymentTerms), days > 0 {
            return days
        }
        if let client, let days = client.paymentTermsDays, days > 0 { return days }
        return max(0, profile.defaultInvoicePaymentTerms)
    }

    static func invoiceNotesSuffix(agreement: AgreementDraft?) -> String? {
        guard let agreement else { return nil }
        var parts: [String] = []
        if !agreement.paymentTerms.isEmpty {
            parts.append(agreement.paymentTerms)
        }
        if !agreement.paymentAmountNotes.isEmpty {
            parts.append(agreement.paymentAmountNotes)
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private static func hourlyRate(
        from agreement: AgreementDraft,
        project: StudioProject,
        profile: StudioProfile
    ) -> Decimal? {
        if let parsed = parseHourlyRate(from: agreement.paymentAmountNotes) { return parsed }
        if let rate = project.hourlyRate, rate > 0 { return rate }
        return profile.defaultHourlyRate
    }

    static func parseHourlyRate(from text: String) -> Decimal? {
        let lower = text.lowercased()
        guard lower.contains("/hr") || lower.contains("hour") || lower.contains("hourly") else { return nil }
        let pattern = #/(\d+(?:\.\d+)?)\s*(?:\/|per)\s*h(?:ou)?r?/#
        if let match = lower.firstMatch(of: pattern), let value = Double(match.1) {
            return Decimal(value)
        }
        let digits = text.split { !$0.isNumber && $0 != "." }.compactMap { Double($0) }
        if let first = digits.first { return Decimal(first) }
        return nil
    }

    // MARK: - Simple Studio

    /// Invoice fields derived from linked job + agreement (mirrors Pro line-item rules).
    public struct SimpleInvoiceDraft: Equatable, Sendable {
        public var amount: Decimal
        public var jobDescription: String
        public var paymentTermsDays: Int
        public var noteSuffix: String?
        public var usedAgreement: Bool
    }

    public static func simpleInvoiceDraft(
        job: SimpleStudioEntry,
        agreement: AgreementDraft?,
        profile: StudioProfile,
        client: StudioClient?
    ) -> SimpleInvoiceDraft {
        let usedAgreement = agreement != nil
        let amount = simpleSuggestedAmount(job: job, agreement: agreement, profile: profile)
        let description = simpleSuggestedDescription(job: job, agreement: agreement)
        let days = paymentTermsDays(agreement: agreement, profile: profile, client: client)
        return SimpleInvoiceDraft(
            amount: amount,
            jobDescription: description,
            paymentTermsDays: days,
            noteSuffix: invoiceNotesSuffix(agreement: agreement),
            usedAgreement: usedAgreement
        )
    }

    public static func simpleSuggestedAmount(
        job: SimpleStudioEntry,
        agreement: AgreementDraft?,
        profile: StudioProfile
    ) -> Decimal {
        guard job.kind == .job else { return 0 }

        if job.resolvedPayStyle == .byTheHour {
            let rate = simpleHourlyRate(job: job, agreement: agreement, profile: profile)
            if rate > 0 {
                let earned = SimpleStudioTimePayEngine.earnings(
                    seconds: job.loggedSeconds ?? 0,
                    hourlyRate: rate
                )
                return max(0, earned - job.paidSoFar)
            }
        }

        if let agreed = job.agreedPrice, agreed > 0 {
            return max(0, agreed - job.paidSoFar)
        }

        if let agreement,
           let fixed = parseFixedAmount(from: agreement.paymentAmountNotes),
           fixed > 0 {
            return max(0, fixed - job.paidSoFar)
        }

        return job.jobBalanceDue
    }

    public static func simpleSuggestedDescription(
        job: SimpleStudioEntry,
        agreement: AgreementDraft?
    ) -> String {
        let label = job.jobLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var base = label.isEmpty ? "Work completed" : label

        if let agreement {
            let deliverables = agreement.deliverables.trimmingCharacters(in: .whitespacesAndNewlines)
            if !deliverables.isEmpty {
                let firstLine = deliverables.components(separatedBy: .newlines).first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? deliverables
                if firstLine.count <= 80 {
                    base = firstLine
                }
            } else if !agreement.scopeBullets.isEmpty {
                let scope = agreement.scopeBullets.trimmingCharacters(in: .whitespacesAndNewlines)
                let first = scope.components(separatedBy: .newlines).first ?? scope
                if first.count <= 80 { base = first }
            }
            if !base.contains("agreement") {
                base += " — per agreement"
            }
        }
        return base
    }

    public static func simpleHourlyRate(
        job: SimpleStudioEntry,
        agreement: AgreementDraft?,
        profile: StudioProfile
    ) -> Decimal {
        if let agreement, let parsed = parseHourlyRate(from: agreement.paymentAmountNotes), parsed > 0 {
            return parsed
        }
        if let rate = job.hourlyRate, rate > 0 { return rate }
        return profile.defaultHourlyRate ?? 0
    }

    public static func parseFixedAmount(from text: String) -> Decimal? {
        let lower = text.lowercased()
        if lower.contains("fixed") || lower.contains("agreed") || lower.contains("total") {
            let digits = text.split { !$0.isNumber && $0 != "." }.compactMap { Double($0) }
            if let last = digits.last { return Decimal(last) }
        }
        return nil
    }

    private static func parsePaymentDays(from terms: String) -> Int? {
        let lower = terms.lowercased()
        let pattern = #/(\d+)\s*day/#
        if let match = lower.firstMatch(of: pattern), let days = Int(match.1) { return days }
        if lower.contains("net 30") { return 30 }
        if lower.contains("net 15") { return 15 }
        if lower.contains("net 7") { return 7 }
        return nil
    }
}
