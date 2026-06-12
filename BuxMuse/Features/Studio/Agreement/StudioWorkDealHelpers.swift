//
//  StudioWorkDealHelpers.swift
//  BuxMuse
//

import Foundation

enum StudioWorkDealHelpers {

    static func agreement(forJob job: SimpleStudioEntry, studioStore: StudioStore) -> AgreementDraft? {
        if let id = job.linkedAgreementId {
            return studioStore.agreementDraft(id: id)
        }
        return studioStore.agreementDraft(forJobEntryId: job.id)
    }

    static func agreement(forProjectId projectId: UUID, studioStore: StudioStore) -> AgreementDraft? {
        studioStore.agreementDraft(forProjectId: projectId)
    }

    static func needsClientApproval(job: SimpleStudioEntry, studioStore: StudioStore) -> Bool {
        guard job.kind == .job else { return false }
        guard let draft = agreement(forJob: job, studioStore: studioStore) else { return true }
        return !draft.hasClientApprovalProof
    }

    static func needsClientApproval(projectId: UUID, studioStore: StudioStore) -> Bool {
        guard let draft = agreement(forProjectId: projectId, studioStore: studioStore) else { return true }
        return !draft.hasClientApprovalProof
    }

    static func agreementStatusChip(for draft: AgreementDraft?) -> String? {
        guard let draft else { return "No agreement" }
        if draft.hasClientApprovalProof { return draft.approvalProofLabel }
        if draft.agreementSentAt != nil { return "Sent" }
        return "Draft"
    }

    static func agreement(
        forSimpleInvoice invoice: SimpleInvoice,
        studioStore: StudioStore,
        simpleStore: SimpleStudioStore
    ) -> AgreementDraft? {
        if let entryId = invoice.linkedEntryId,
           let job = simpleStore.entry(id: entryId) {
            return agreement(forJob: job, studioStore: studioStore)
        }
        return studioStore.agreementDrafts.first { $0.linkedInvoiceId == invoice.id }
    }

    static func linkedJob(
        forSimpleInvoice invoice: SimpleInvoice,
        simpleStore: SimpleStudioStore
    ) -> SimpleStudioEntry? {
        guard let entryId = invoice.linkedEntryId else { return nil }
        return simpleStore.entry(id: entryId)
    }

    static func agreement(
        forProInvoice invoice: StudioInvoice,
        studioStore: StudioStore
    ) -> AgreementDraft? {
        if let draft = studioStore.agreementDrafts.first(where: { $0.linkedInvoiceId == invoice.id }) {
            return draft
        }
        if let projectId = invoice.projectId {
            return agreement(forProjectId: projectId, studioStore: studioStore)
        }
        return nil
    }

    static func linkedProject(
        forProInvoice invoice: StudioInvoice,
        studioStore: StudioStore
    ) -> StudioProject? {
        guard let projectId = invoice.projectId else { return nil }
        return studioStore.project(id: projectId)
    }
}
