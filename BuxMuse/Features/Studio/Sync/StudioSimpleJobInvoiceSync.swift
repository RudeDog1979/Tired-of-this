//
//  StudioSimpleJobInvoiceSync.swift
//  BuxMuse
//
//  Two-way sync between Simple Studio jobs and linked simple invoices.
//

import Foundation

@MainActor
enum StudioSimpleJobInvoiceSync {

    private static var isSyncing = false

    // MARK: - Public entry points

    static func linkAndSync(
        invoiceId: UUID,
        jobEntryId: UUID,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) {
        StudioSyncCoordinator.linkSimpleInvoiceToJob(
            invoiceId: invoiceId,
            jobEntryId: jobEntryId,
            store: store
        )
        guard let job = store.entry(id: jobEntryId),
              store.invoice(id: invoiceId) != nil else { return }
        syncJobToInvoiceUnlocked(job: job, invoiceId: invoiceId, store: store, studioStore: studioStore)
    }

    static func afterJobUpdated(
        _ job: SimpleStudioEntry,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) {
        guard job.kind == .job, let invoiceId = job.linkedInvoiceId else { return }
        perform {
            syncJobToInvoiceUnlocked(job: job, invoiceId: invoiceId, store: store, studioStore: studioStore)
        }
    }

    static func afterInvoiceUpdated(
        _ invoice: SimpleInvoice,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) {
        perform {
            syncInvoiceToJobUnlocked(invoice: invoice, store: store, studioStore: studioStore)
        }
    }

    static func afterInvoiceCreated(
        _ invoice: SimpleInvoice,
        jobEntryId: UUID?,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) {
        perform {
            if let jobEntryId {
                linkAndSync(invoiceId: invoice.id, jobEntryId: jobEntryId, store: store, studioStore: studioStore)
            } else {
                applyAgreementToOpenInvoice(
                    invoiceId: invoice.id,
                    jobEntryId: nil,
                    store: store,
                    studioStore: studioStore
                )
            }
        }
    }

    static func afterJobMarkedPaid(
        jobId: UUID,
        store: SimpleStudioStore
    ) {
        guard let job = store.entry(id: jobId),
              let invoiceId = job.linkedInvoiceId,
              var invoice = store.invoice(id: invoiceId),
              invoice.status != .paid else { return }
        perform {
            invoice.status = .paid
            invoice.paidAt = Date()
            invoice.amount = max(invoice.amount, job.paidSoFar > 0 ? job.paidSoFar : invoice.amount)
            store.replaceInvoice(invoice)
            StudioSyncCoordinator.markSimpleInvoicePaidCascade(invoiceId: invoiceId, store: store)
        }
    }

    static func afterInvoiceMarkedPaid(
        invoiceId: UUID,
        store: SimpleStudioStore
    ) {
        guard let invoice = store.invoice(id: invoiceId) else { return }
        perform {
            if let jobId = invoice.linkedEntryId,
               var job = store.entry(id: jobId),
               job.kind == .job,
               job.paymentStatus != .paid {
                if let agreed = job.agreedPrice, agreed > 0 {
                    job.amount = agreed
                } else if invoice.amount > 0 {
                    job.amount = invoice.amount
                }
                job.paymentStatus = .paid
                store.replaceEntry(job)
            }
            for entry in store.entries where entry.linkedInvoiceId == invoiceId {
                var copy = entry
                copy.paymentStatus = .paid
                if entry.kind == .owedToMe { copy.amount = invoice.amount }
                store.replaceEntry(copy)
            }
        }
    }

    // MARK: - Agreement on every save path

    static func applyAgreementToOpenInvoice(
        invoiceId: UUID,
        jobEntryId: UUID?,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) {
        guard var invoice = store.invoice(id: invoiceId),
              invoice.status != .paid,
              let jobId = jobEntryId ?? invoice.linkedEntryId,
              let job = store.entry(id: jobId) else { return }

        let agreement = StudioWorkDealHelpers.agreement(forJob: job, studioStore: studioStore)
        let client = studioStore.clients.first(where: {
            $0.name.caseInsensitiveCompare(job.customerName) == .orderedSame
        })
        let draft = StudioAgreementInvoiceLines.simpleInvoiceDraft(
            job: job,
            agreement: agreement,
            profile: studioStore.profile,
            client: client
        )

        perform {
            if draft.amount > 0 { invoice.amount = draft.amount }
            if !draft.jobDescription.isEmpty { invoice.jobDescription = draft.jobDescription }
            if invoice.customerName.isEmpty { invoice.customerName = job.customerName }
            if invoice.customerId == nil { invoice.customerId = job.customerId }
            store.replaceInvoice(invoice)

            if let agreement {
                var deal = agreement
                deal.linkedInvoiceId = invoice.id
                deal.linkedJobEntryId = job.id
                studioStore.upsertAgreementDraft(deal, simpleStore: store)
            }
        }
    }

    // MARK: - Core sync

    private static func syncJobToInvoiceUnlocked(
        job: SimpleStudioEntry,
        invoiceId: UUID,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) {
        guard var invoice = store.invoice(id: invoiceId) else { return }
            invoice.linkedEntryId = job.id
            invoice.customerName = job.customerName
            invoice.customerId = job.customerId
            let label = job.jobLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !label.isEmpty { invoice.jobDescription = label }

            if invoice.status != .paid {
                let balance = StudioAgreementInvoiceLines.simpleSuggestedAmount(
                    job: job,
                    agreement: StudioWorkDealHelpers.agreement(forJob: job, studioStore: studioStore),
                    profile: studioStore.profile
                )
                if balance > 0 { invoice.amount = balance }
            } else if job.paidSoFar > 0 {
                invoice.amount = max(invoice.amount, job.paidSoFar)
            }

            store.replaceInvoice(invoice)
            syncOwedToMeMirror(invoice: invoice, store: store)
            applyAgreementToOpenInvoice(
                invoiceId: invoiceId,
                jobEntryId: job.id,
                store: store,
                studioStore: studioStore
            )
    }

    private static func syncInvoiceToJobUnlocked(
        invoice: SimpleInvoice,
        store: SimpleStudioStore,
        studioStore: StudioStore
    ) {
        guard let jobId = invoice.linkedEntryId,
              var job = store.entry(id: jobId),
              job.kind == .job else { return }
            job.linkedInvoiceId = invoice.id
            job.customerName = invoice.customerName
            if let customerId = invoice.customerId { job.customerId = customerId }

            let description = invoice.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty { job.jobLabel = description }

            if invoice.status == .paid {
                if job.paymentStatus != .paid {
                    job.paymentStatus = .paid
                    if invoice.amount > 0 { job.amount = max(job.amount, invoice.amount) }
                }
            } else {
                switch job.resolvedPayStyle {
                case .onePrice:
                    let targetAgreed = invoice.amount + job.paidSoFar
                    if targetAgreed > 0 { job.agreedPrice = targetAgreed }
                case .byTheHour:
                    break
                }
            }

            store.replaceEntry(job)
            syncOwedToMeMirror(invoice: invoice, store: store)

            if invoice.status != .paid {
                applyAgreementToOpenInvoice(
                    invoiceId: invoice.id,
                    jobEntryId: job.id,
                    store: store,
                    studioStore: studioStore
                )
            }
    }

    private static func syncOwedToMeMirror(invoice: SimpleInvoice, store: SimpleStudioStore) {
        guard let idx = store.entries.firstIndex(where: {
            $0.linkedInvoiceId == invoice.id && $0.kind == .owedToMe
        }) else { return }
        var entry = store.entries[idx]
        entry.amount = invoice.amount
        entry.customerName = invoice.customerName
        entry.customerId = invoice.customerId
        entry.jobLabel = invoice.jobDescription
        entry.paymentStatus = invoice.status == .paid ? .paid : .unpaid
        store.replaceEntry(entry)
    }

    private static func perform(_ work: () -> Void) {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        work()
    }
}
