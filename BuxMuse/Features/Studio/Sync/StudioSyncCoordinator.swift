//
//  StudioSyncCoordinator.swift
//  BuxMuse
//
//  Cross-module links (project ↔ invoice ↔ job) without replacing existing stores.
//

import Foundation

@MainActor
enum StudioSyncCoordinator {

    // MARK: - Project ↔ invoice

    /// Keeps `StudioProject.generatedInvoiceIds` in sync when invoices reference a project.
    static func registerInvoiceProjectLink(_ invoice: StudioInvoice, store: StudioStore) {
        guard let projectId = invoice.projectId else { return }
        guard var project = store.projects.first(where: { $0.id == projectId }) else { return }
        guard !project.generatedInvoiceIds.contains(invoice.id) else { return }
        project.generatedInvoiceIds.append(invoice.id)
        store.updateProject(project)
    }

    static func unregisterInvoiceProjectLink(invoiceId: UUID, projectId: UUID?, store: StudioStore) {
        guard let projectId else { return }
        guard var project = store.projects.first(where: { $0.id == projectId }) else { return }
        let before = project.generatedInvoiceIds.count
        project.generatedInvoiceIds.removeAll { $0 == invoiceId }
        guard project.generatedInvoiceIds.count != before else { return }
        store.updateProject(project)
    }

    // MARK: - Simple job ↔ invoice (additive)

    static func linkSimpleInvoiceToJob(
        invoiceId: UUID,
        jobEntryId: UUID,
        store: SimpleStudioStore
    ) {
        guard var invoice = store.invoice(id: invoiceId) else { return }
        invoice.linkedEntryId = jobEntryId
        store.updateInvoice(invoice)

        guard var job = store.entry(id: jobEntryId), job.kind == .job else { return }
        job.linkedInvoiceId = invoiceId
        store.updateEntry(job)
    }

    static func markSimpleInvoicePaidCascade(
        invoiceId: UUID,
        store: SimpleStudioStore
    ) {
        guard let invoice = store.invoice(id: invoiceId),
              let jobId = invoice.linkedEntryId,
              var job = store.entry(id: jobId),
              job.kind == .job else { return }
        if job.paymentStatus != .paid {
            job.paymentStatus = .paid
            store.updateEntry(job)
        }
    }

    // MARK: - Agreement ↔ project / client

    /// Aligns agreement links with project client and optional invoice reference.
    static func alignAgreementDraft(_ draft: inout AgreementDraft, store: StudioStore) {
        if let projectId = draft.projectId,
           let project = store.projects.first(where: { $0.id == projectId }) {
            if draft.clientId == nil {
                draft.clientId = project.clientId
            }
        }
        if let invoiceId = draft.linkedInvoiceId,
           let invoice = store.invoices.first(where: { $0.id == invoiceId }) {
            if draft.clientId == nil { draft.clientId = invoice.clientId }
            if draft.projectId == nil { draft.projectId = invoice.projectId }
        }
        if let path = draft.signedDocumentPath {
            draft.signedDocumentPath = AgreementDocumentStore.normalizedStoredPath(path)
        }
        draft.refreshAgreementStatus()
    }

    /// Keeps `SimpleStudioEntry.linkedAgreementId` ↔ `AgreementDraft.linkedJobEntryId` in sync.
    static func linkAgreementToJob(
        draft: AgreementDraft,
        simpleStore: SimpleStudioStore
    ) {
        guard let jobId = draft.linkedJobEntryId else { return }
        guard var job = simpleStore.entry(id: jobId), job.kind == .job else { return }
        if job.linkedAgreementId != draft.id {
            job.linkedAgreementId = draft.id
            simpleStore.updateEntry(job)
        }
    }

    static func unlinkAgreementFromJob(
        agreementId: UUID,
        jobEntryId: UUID?,
        simpleStore: SimpleStudioStore
    ) {
        guard let jobId = jobEntryId ?? simpleStore.entries.first(where: { $0.linkedAgreementId == agreementId })?.id else {
            return
        }
        guard var job = simpleStore.entry(id: jobId) else { return }
        if job.linkedAgreementId == agreementId {
            job.linkedAgreementId = nil
            simpleStore.updateEntry(job)
        }
    }
}
