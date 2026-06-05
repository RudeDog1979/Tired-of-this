//
//  SimpleStudioStore.swift
//  BuxMuse
//
//  Offline JSON store for Simple Studio entries, customers, and invoices.
//

import Foundation
import Combine

@MainActor
public final class SimpleStudioStore: ObservableObject {
    public static let shared = SimpleStudioStore()

    @Published public private(set) var entries: [SimpleStudioEntry] = []
    @Published public private(set) var customers: [SimpleCustomerMemory] = []
    @Published public private(set) var invoices: [SimpleInvoice] = []
    @Published public var hourlyRateHint: Decimal?
    @Published public private(set) var businessCard: SimpleBusinessCard?

    private let saveQueue = DispatchQueue(label: "com.buxmuse.simplestudio.save", qos: .utility)
    private var isLoaded = false

    private init() {
        loadStore()
    }

    private static let storeFileName = "simple_studio.json"

    private var storeDirectory: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Studio", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var storeURL: URL {
        storeDirectory.appendingPathComponent(Self.storeFileName)
    }

    public var snapshot: SimpleStudioSnapshot {
        SimpleStudioSnapshot(
            entries: entries,
            customers: customers,
            invoices: invoices,
            hourlyRateHint: hourlyRateHint,
            businessCard: businessCard
        )
    }

    public func loadStore() {
        guard !isLoaded else { return }
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            isLoaded = true
            return
        }
        do {
            let data = try Data(contentsOf: storeURL)
            let decoded = try JSONDecoder().decode(SimpleStudioSnapshot.self, from: data)
            entries = decoded.entries.map { entry in
                var normalized = entry
                if let path = entry.sourcePhotoPath {
                    normalized.sourcePhotoPath = SimpleStudioScanImageStore.normalizedStoredPath(path)
                }
                return normalized
            }
            customers = decoded.customers
            invoices = decoded.invoices
            hourlyRateHint = decoded.hourlyRateHint
            if var card = decoded.businessCard {
                if let path = card.photoPath {
                    card.photoPath = SimpleStudioScanImageStore.normalizedStoredPath(path)
                }
                businessCard = card
            }
            isLoaded = true
        } catch {
            print("SimpleStudioStore: decode error \(error)")
            isLoaded = true
        }
    }

    public func save() {
        let payload = snapshot
        let url = storeURL
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("SimpleStudioStore: save error \(error)")
        }
    }

    public func addEntry(_ entry: SimpleStudioEntry) {
        entries.insert(entry, at: 0)
        upsertCustomer(from: entry)
        refreshCustomerStats(for: entry.customerName)
        save()
    }

    public func updateEntry(_ entry: SimpleStudioEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        upsertCustomer(from: entry)
        refreshCustomerStats(for: entry.customerName)
        save()
        if entry.kind == .job {
            StudioSimpleJobInvoiceSync.afterJobUpdated(entry, store: self, studioStore: .shared)
        }
    }

    /// Internal replace without triggering job↔invoice sync loops.
    func replaceEntry(_ entry: SimpleStudioEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        upsertCustomer(from: entry)
        refreshCustomerStats(for: entry.customerName)
        save()
    }

    func replaceInvoice(_ invoice: SimpleInvoice) {
        guard let idx = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[idx] = invoice
        save()
    }

    public func entry(id: UUID) -> SimpleStudioEntry? {
        entries.first { $0.id == id }
    }

    public func invoice(id: UUID) -> SimpleInvoice? {
        invoices.first { $0.id == id }
    }

    public func markEntryPaid(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        if entries[idx].kind == .job, let agreed = entries[idx].agreedPrice {
            entries[idx].amount = agreed
        }
        entries[idx].paymentStatus = .paid
        refreshCustomerStats(for: entries[idx].customerName)
        save()
        if entries[idx].kind == .job {
            StudioSimpleJobInvoiceSync.afterJobMarkedPaid(jobId: id, store: self)
        }
    }

    public func markEntryUnpaid(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        if entries[idx].kind == .job {
            entries[idx].amount = 0
        }
        entries[idx].paymentStatus = .unpaid
        refreshCustomerStats(for: entries[idx].customerName)
        save()
    }

    public func updateCustomer(id: UUID, name: String, phone: String, notes: String) {
        guard let idx = customers.firstIndex(where: { $0.id == id }) else { return }
        let oldName = customers[idx].name
        customers[idx].name = name
        customers[idx].phone = phone.isEmpty ? nil : phone
        customers[idx].notes = notes.isEmpty ? nil : notes
        customers[idx].lastSeen = Date()

        if oldName.localizedCaseInsensitiveCompare(name) != .orderedSame {
            for entryIdx in entries.indices where entries[entryIdx].customerName.localizedCaseInsensitiveCompare(oldName) == .orderedSame {
                entries[entryIdx].customerName = name
                entries[entryIdx].customerId = customers[idx].id
            }
            for invoiceIdx in invoices.indices where invoices[invoiceIdx].customerName.localizedCaseInsensitiveCompare(oldName) == .orderedSame {
                invoices[invoiceIdx].customerName = name
                invoices[invoiceIdx].customerId = customers[idx].id
            }
        }
        refreshCustomerStats(for: name)
        save()
    }

    public func saveCustomerPhone(name: String, phone: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else { return }
        if var existing = customer(named: trimmedName) {
            existing.phone = trimmedPhone
            existing.lastSeen = Date()
            if let idx = customers.firstIndex(where: { $0.id == existing.id }) {
                customers[idx] = existing
            }
        } else {
            customers.append(SimpleCustomerMemory(name: trimmedName, phone: trimmedPhone))
        }
        save()
    }

    public func customer(id: UUID) -> SimpleCustomerMemory? {
        customers.first { $0.id == id }
    }

    public func refreshCustomerStats(for name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var person = customer(named: trimmed),
              let idx = customers.firstIndex(where: { $0.id == person.id }) else { return }

        let related = entries.filter {
            $0.customerName.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }

        person.outstandingBalance = related.reduce(Decimal(0)) { partial, entry in
            switch entry.kind {
            case .job where !entry.isJobFullyPaid:
                return partial + entry.jobBalanceDue
            case .owedToMe where entry.paymentStatus != .paid:
                return partial + entry.amount
            default:
                return partial
            }
        }

        person.completedJobs = related.filter { $0.kind == .job }.count
        person.totalEarned = related.reduce(Decimal(0)) { partial, entry in
            switch entry.kind {
            case .job, .income, .repaymentReceived:
                return partial + entry.paidSoFar + (entry.tip ?? 0)
            default:
                return partial
            }
        }

        if let latest = related.sorted(by: { $0.createdAt > $1.createdAt }).first {
            person.lastSeen = latest.createdAt
            person.lastAmount = latest.amount
            person.lastJobLabel = latest.jobLabel
        }

        customers[idx] = person
    }

    public func addInvoice(_ invoice: SimpleInvoice) {
        invoices.insert(invoice, at: 0)
        if !invoice.customerName.isEmpty {
            upsertCustomer(name: invoice.customerName, amount: invoice.amount, jobLabel: invoice.jobDescription)
        }
        entries.insert(
            SimpleStudioEntry(
                kind: .owedToMe,
                amount: invoice.amount,
                customerName: invoice.customerName,
                customerId: invoice.customerId,
                jobLabel: invoice.jobDescription,
                paymentStatus: invoice.status == .paid ? .paid : .unpaid,
                linkedInvoiceId: invoice.id
            ),
            at: 0
        )
        save()
    }

    public func updateInvoice(_ invoice: SimpleInvoice) {
        guard let idx = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[idx] = invoice
        save()
        StudioSimpleJobInvoiceSync.afterInvoiceUpdated(invoice, store: self, studioStore: .shared)
    }

    public func markInvoicePaid(id: UUID) {
        guard let idx = invoices.firstIndex(where: { $0.id == id }) else { return }
        invoices[idx].status = .paid
        invoices[idx].paidAt = Date()
        save()
        StudioSimpleJobInvoiceSync.afterInvoiceMarkedPaid(invoiceId: id, store: self)
        StudioSyncCoordinator.markSimpleInvoicePaidCascade(invoiceId: id, store: self)
    }

    /// Removes a Simple invoice and unlinks related entries. Does not delete a linked Pro copy (Option A).
    public func deleteInvoice(id: UUID) {
        unlinkAndRemoveEntries(forDeletedInvoice: id)
        invoices.removeAll { $0.id == id }
        save()
    }

    func unlinkAndRemoveEntries(forDeletedInvoice invoiceId: UUID) {
        entries.removeAll { $0.linkedInvoiceId == invoiceId && $0.kind == .owedToMe }
        for idx in entries.indices where entries[idx].linkedInvoiceId == invoiceId {
            entries[idx].linkedInvoiceId = nil
        }
    }

    /// Appends stopwatch time from Simple Studio Log Time onto a job entry.
    public func appendLoggedTime(jobEntryId: UUID, duration: TimeInterval, sessionNote: String?) {
        guard duration > 0, var job = entry(id: jobEntryId), job.kind == .job else { return }
        job.loggedSeconds = (job.loggedSeconds ?? 0) + duration
        let trimmed = sessionNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            let stamp = StudioTimerSession.formattedDuration(duration)
            let line = "Logged \(stamp): \(trimmed)"
            if let existing = job.note?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
                job.note = existing + "\n" + line
            } else {
                job.note = line
            }
        }
        updateEntry(job)
    }

    public var activeJobEntries: [SimpleStudioEntry] {
        entries.filter { $0.kind == .job }
    }

    public func customer(named name: String) -> SimpleCustomerMemory? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return customers.first {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    public func recentCustomerNames(limit: Int = 5) -> [SimpleCustomerMemory] {
        Array(customers.sorted { $0.lastSeen > $1.lastSeen }.prefix(limit))
    }

    public func saveBusinessCard(_ card: SimpleBusinessCard) {
        businessCard = card
        save()
    }

    public func resetAllData() {
        entries = []
        customers = []
        invoices = []
        hourlyRateHint = nil
        businessCard = nil
        if FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
    }

    public func apply(_ snapshot: SimpleStudioSnapshot) {
        entries = snapshot.entries
        customers = snapshot.customers
        invoices = snapshot.invoices
        hourlyRateHint = snapshot.hourlyRateHint
        businessCard = snapshot.businessCard
        save()
    }

    private func upsertCustomer(from entry: SimpleStudioEntry) {
        let name = entry.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        upsertCustomer(name: name, amount: entry.amount, jobLabel: entry.jobLabel, entry: entry)
    }

    private func upsertCustomer(
        name: String,
        amount: Decimal,
        jobLabel: String?,
        entry: SimpleStudioEntry? = nil
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var existing = customer(named: trimmed) {
            existing.lastSeen = Date()
            existing.lastAmount = amount
            existing.lastJobLabel = jobLabel
            if entry?.kind == .job || entry?.kind == .income {
                existing.totalEarned += amount
                if entry?.kind == .job { existing.completedJobs += 1 }
            }
            if entry?.kind == .owedToMe, entry?.paymentStatus != .paid {
                existing.outstandingBalance += amount
            }
            if let idx = customers.firstIndex(where: { $0.id == existing.id }) {
                customers[idx] = existing
            }
        } else {
            var outstanding: Decimal = 0
            if entry?.kind == .owedToMe, entry?.paymentStatus != .paid {
                outstanding = amount
            }
            customers.append(SimpleCustomerMemory(
                name: trimmed,
                lastAmount: amount,
                lastJobLabel: jobLabel,
                totalEarned: (entry?.kind == .income || entry?.kind == .job) ? amount : 0,
                outstandingBalance: outstanding,
                completedJobs: entry?.kind == .job ? 1 : 0
            ))
        }
    }
}
