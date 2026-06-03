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
