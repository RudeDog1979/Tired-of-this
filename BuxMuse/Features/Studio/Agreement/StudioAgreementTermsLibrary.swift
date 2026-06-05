//
//  StudioAgreementTermsLibrary.swift
//  BuxMuse
//
//  Pre-made T&C clauses (editable per agreement; not legal advice).
//

import Foundation

public struct StudioAgreementTermsClause: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: StudioAgreementTermsCategory
    public let defaultBody: String

    public init(id: String, title: String, category: StudioAgreementTermsCategory, defaultBody: String) {
        self.id = id
        self.title = title
        self.category = category
        self.defaultBody = defaultBody
    }

    public func catalogDefaultBody(locale: Locale) -> String {
        BuxCatalogLabel.string("agreement.body.\(id)", locale: locale)
    }
}

public enum StudioAgreementTermsCategory: String, CaseIterable, Sendable {
    case payment
    case scheduling
    case scope
    case legal
    case privacy
    case other

    public var label: String {
        switch self {
        case .payment: "Payment & money"
        case .scheduling: "Scheduling & cancellation"
        case .scope: "Scope & deliverables"
        case .legal: "Legal & general"
        case .privacy: "Privacy & data"
        case .other: "Other"
        }
    }
}

public enum StudioAgreementTermsPack: String, CaseIterable, Identifiable, Sendable {
    case essential
    case freelance
    case trade
    case full

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .essential: "Essential (recommended)"
        case .freelance: "Freelance & creative"
        case .trade: "Trade & on-site work"
        case .full: "Full set (all clauses)"
        }
    }

    public var subtitle: String {
        switch self {
        case .essential: "Deposit, payment, cancellations, scope changes, liability"
        case .freelance: "Essential + revisions, IP, late fees"
        case .trade: "Essential + reschedule, materials, workmanship, site safety"
        case .full: "All 19 clauses — review and trim what you need"
        }
    }
}

public enum StudioAgreementTermsLibrary {

    public static let disclaimer =
        "Template wording for your business records only — not legal advice. Adjust for your jurisdiction and situation."

    public static let allClauses: [StudioAgreementTermsClause] = [
        StudioAgreementTermsClause(
            id: "deposit",
            title: "Deposit & booking fee",
            category: .payment,
            defaultBody: """
            A non-refundable deposit may be required to reserve the job or start date. The deposit is applied to the final invoice. \
            If the client cancels after work has been scheduled or started, the deposit may be retained to cover lost time and costs.
            """
        ),
        StudioAgreementTermsClause(
            id: "payment-due",
            title: "Payment due",
            category: .payment,
            defaultBody: """
            Unless agreed otherwise in writing, payment is due on the due date shown on the invoice. \
            Work may pause if payment is overdue. The provider may charge reasonable costs for chasing late payment where permitted by law.
            """
        ),
        StudioAgreementTermsClause(
            id: "late-payment",
            title: "Late payment",
            category: .payment,
            defaultBody: """
            Overdue balances may incur interest or a late fee at the rate allowed by local law (or as stated on the invoice). \
            The client remains responsible for the full agreed price plus any approved extras.
            """
        ),
        StudioAgreementTermsClause(
            id: "retainer",
            title: "Retainer & ongoing work",
            category: .payment,
            defaultBody: """
            Where a monthly or recurring retainer applies, it is due in advance and covers the hours or services stated in the scope. \
            Unused retainer time may expire at period end unless otherwise agreed. Work above the retainer is quoted or billed at the agreed rate.
            """
        ),
        StudioAgreementTermsClause(
            id: "rush-fee",
            title: "Rush & expedited work",
            category: .payment,
            defaultBody: """
            Requests for faster turnaround, evenings, weekends, or work that displaces other booked jobs may incur a rush or priority fee. \
            The fee and revised deadline will be confirmed in writing before expedited work begins.
            """
        ),
        StudioAgreementTermsClause(
            id: "expenses",
            title: "Materials & expenses",
            category: .payment,
            defaultBody: """
            Materials, travel, parking, permits, and third-party costs are billed as agreed in advance or at cost plus an agreed markup. \
            Unexpected costs will be discussed with the client before being incurred where practical.
            """
        ),
        StudioAgreementTermsClause(
            id: "cancellation-client",
            title: "Cancellation by client",
            category: .scheduling,
            defaultBody: """
            The client should give as much notice as possible. Cancellations with little or no notice after a booking is confirmed may result in \
            charges for time already reserved, travel, or materials ordered. Any deposit may be non-refundable as stated above.
            """
        ),
        StudioAgreementTermsClause(
            id: "cancellation-provider",
            title: "Cancellation by provider",
            category: .scheduling,
            defaultBody: """
            The provider will make reasonable efforts to complete the work as agreed. If the provider must cancel, \
            the client will be notified promptly and any deposit or prepayment for unperformed work will be refunded or rescheduled by agreement.
            """
        ),
        StudioAgreementTermsClause(
            id: "reschedule",
            title: "Rescheduling",
            category: .scheduling,
            defaultBody: """
            Either party may request a reschedule by mutual agreement. Repeated reschedules by the client may affect availability and pricing. \
            A fee may apply for short-notice changes where time has already been blocked.
            """
        ),
        StudioAgreementTermsClause(
            id: "scope-changes",
            title: "Scope changes & extra work",
            category: .scope,
            defaultBody: """
            Work outside the agreed scope, deliverables, or quote requires client approval before proceeding. \
            Extra work is billed at the agreed rate or a new quote. Verbal requests should be confirmed in writing where possible.
            """
        ),
        StudioAgreementTermsClause(
            id: "revisions",
            title: "Revisions",
            category: .scope,
            defaultBody: """
            The agreed price includes the number of revision rounds stated in the scope. Additional rounds or major changes after approval \
            may be billed as extra work at the provider's standard rate.
            """
        ),
        StudioAgreementTermsClause(
            id: "warranty",
            title: "Workmanship & defects",
            category: .scope,
            defaultBody: """
            The provider will remedy genuine defects in workmanship attributable to the provider within a reasonable period after completion, \
            if reported promptly in writing. This does not cover normal wear, client-supplied materials, third-party products, or misuse.
            """
        ),
        StudioAgreementTermsClause(
            id: "ip",
            title: "Ownership of work",
            category: .legal,
            defaultBody: """
            Upon full payment, the client receives the agreed usage rights to deliverables created for this project, unless otherwise stated. \
            The provider may retain the right to show non-confidential work in a portfolio unless the client objects in writing.
            """
        ),
        StudioAgreementTermsClause(
            id: "confidentiality",
            title: "Confidentiality",
            category: .legal,
            defaultBody: """
            Both parties will keep non-public business information shared for this project confidential, except where disclosure is required by law \
            or already public through no fault of the receiving party.
            """
        ),
        StudioAgreementTermsClause(
            id: "gdpr",
            title: "Personal data (GDPR / privacy)",
            category: .privacy,
            defaultBody: """
            Each party will process personal data only as needed to perform this agreement and in line with applicable privacy law (including UK/EU GDPR where relevant). \
            Contact details and project files are used for delivery, invoicing, and records. The client should not share third-party personal data without a lawful basis. \
            Data may be stored on the provider's devices or tools; the client may request reasonable access or correction of their own data.
            """
        ),
        StudioAgreementTermsClause(
            id: "liability",
            title: "Limitation of liability",
            category: .legal,
            defaultBody: """
            To the fullest extent permitted by law, the provider's total liability for claims relating to this agreement is limited to the fees \
            paid by the client for the work giving rise to the claim. Neither party is liable for indirect or consequential loss except where liability cannot be excluded.
            """
        ),
        StudioAgreementTermsClause(
            id: "independent-contractor",
            title: "Independent contractor",
            category: .legal,
            defaultBody: """
            The provider is an independent contractor, not an employee or agent of the client. The provider is responsible for their own tax, insurance, \
            and compliance obligations unless explicitly agreed otherwise in writing.
            """
        ),
        StudioAgreementTermsClause(
            id: "force-majeure",
            title: "Events outside our control",
            category: .legal,
            defaultBody: """
            Neither party is in breach for delay or failure caused by events outside reasonable control (e.g. severe weather, illness, supply shortages, \
            government action). Affected dates and costs will be renegotiated in good faith.
            """
        ),
        StudioAgreementTermsClause(
            id: "disputes",
            title: "Disputes",
            category: .legal,
            defaultBody: """
            The parties will try to resolve disputes informally first. If that fails, disputes may be referred to mediation or courts in the jurisdiction \
            agreed by both parties (or where the provider ordinarily conducts business if none is stated).
            """
        ),
        StudioAgreementTermsClause(
            id: "site-safety",
            title: "Site access & safety",
            category: .other,
            defaultBody: """
            The client will provide safe, lawful access to the work area. The client is responsible for informing the provider of hazards, pets, children, \
            utilities, and building rules. Work may stop if conditions are unsafe.
            """
        ),
    ]

    public static func clause(id: String) -> StudioAgreementTermsClause? {
        allClauses.first { $0.id == id }
    }

    public static func clauseIds(for pack: StudioAgreementTermsPack) -> [String] {
        switch pack {
        case .essential:
            return ["deposit", "payment-due", "cancellation-client", "scope-changes", "liability"]
        case .freelance:
            return clauseIds(for: .essential) + [
                "revisions", "ip", "late-payment", "rush-fee", "retainer",
                "cancellation-provider", "gdpr"
            ]
        case .trade:
            return clauseIds(for: .essential) + [
                "reschedule", "expenses", "warranty", "site-safety", "rush-fee",
                "cancellation-provider"
            ]
        case .full:
            return allClauses.map(\.id)
        }
    }

    public static var defaultEnabledClauseIds: [String] {
        clauseIds(for: .essential)
    }
}
