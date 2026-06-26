//
//  SimpleStudioProMigration.swift
//  BuxMuse
//
//  Merges Simple Studio data into Pro Studio on upgrade — nothing lost.
//

import Foundation

struct SimpleStudioMigrationResult: Equatable {
    var clientsAdded: Int = 0
    var invoicesAdded: Int = 0
    var receiptsAdded: Int = 0
    var projectsAdded: Int = 0

    var total: Int { clientsAdded + invoicesAdded + receiptsAdded + projectsAdded }
}

enum SimpleStudioProMigration {

    /// Import Simple Studio records into Pro structures. Idempotent — skips IDs already present in Pro.
    @MainActor
    static func migrate(
        simple snapshot: SimpleStudioSnapshot,
        into studioStore: StudioStore,
        currencyCode: String
    ) -> SimpleStudioMigrationResult {
        var result = SimpleStudioMigrationResult()
        var clientIdByName: [String: UUID] = Dictionary(
            uniqueKeysWithValues: studioStore.clients.map { ($0.name.lowercased(), $0.id) }
        )

        // 1. Customers → Clients
        for memory in snapshot.customers {
            let key = memory.name.lowercased()
            if clientIdByName[key] != nil { continue }

            var notes = "Imported from Simple Studio."
            if memory.totalEarned > 0 {
                notes += " Total earned: \(memory.totalEarned)."
            }
            if memory.outstandingBalance > 0 {
                notes += " Outstanding: \(memory.outstandingBalance)."
            }
            if memory.completedJobs > 0 {
                notes += " Jobs: \(memory.completedJobs)."
            }

            let client = StudioClient(
                id: memory.id,
                name: memory.name,
                phone: memory.phone ?? "",
                notes: notes
            )
            studioStore.addClient(client)
            clientIdByName[key] = memory.id
            result.clientsAdded += 1
        }

        func resolveClientId(name: String, explicitId: UUID?) -> UUID? {
            if let explicitId, studioStore.clients.contains(where: { $0.id == explicitId }) {
                return explicitId
            }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            if let existing = clientIdByName[key] { return existing }
            if let existing = studioStore.clients.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
                clientIdByName[key] = existing.id
                return existing.id
            }
            let client = StudioClient(name: trimmed, notes: "Imported from Simple Studio.")
            studioStore.addClient(client)
            clientIdByName[key] = client.id
            result.clientsAdded += 1
            return client.id
        }

        // 2. Simple invoices → Pro invoices
        for simpleInvoice in snapshot.invoices {
            guard !studioStore.invoices.contains(where: { $0.id == simpleInvoice.id }) else { continue }
            guard let clientId = resolveClientId(name: simpleInvoice.customerName, explicitId: simpleInvoice.customerId) else {
                continue
            }

            let lineItem = StudioInvoiceLineItem(
                description: simpleInvoice.jobDescription,
                quantity: 1,
                unitPrice: simpleInvoice.amount
            )
            let status: InvoiceStatus = {
                switch simpleInvoice.status {
                case .paid: return .paid
                case .draft: return .draft
                case .sent: return .sent
                }
            }()

            let invoice = StudioInvoice(
                id: simpleInvoice.id,
                clientId: clientId,
                invoiceNumber: studioStore.nextInvoiceNumber(),
                issueDate: simpleInvoice.createdAt,
                dueDate: simpleInvoice.createdAt.addingTimeInterval(14 * 86400),
                status: status,
                currencyCode: currencyCode,
                lineItems: [lineItem],
                subtotal: simpleInvoice.amount,
                taxAmount: 0,
                total: simpleInvoice.amount,
                notes: "Imported from Simple Studio.",
                paymentDate: simpleInvoice.paidAt,
                externalReference: "simple-invoice"
            )
            studioStore.addInvoice(invoice)
            result.invoicesAdded += 1
        }

        // 3. Entries → invoices, receipts, projects
        for entry in snapshot.entries {
            if entry.linkedInvoiceId != nil,
               snapshot.invoices.contains(where: { $0.id == entry.linkedInvoiceId }) {
                continue
            }

            let clientId = resolveClientId(name: entry.customerName, explicitId: entry.customerId)

            switch entry.kind {
            case .job:
                migrateJobEntry(
                    entry,
                    clientId: clientId,
                    studioStore: studioStore,
                    currencyCode: currencyCode,
                    result: &result
                )
            case .income, .repaymentReceived:
                migrateIncomeEntry(
                    entry,
                    clientId: clientId,
                    studioStore: studioStore,
                    currencyCode: currencyCode,
                    result: &result
                )
            case .expense, .iOwe:
                migrateExpenseEntry(entry, clientId: clientId, studioStore: studioStore, currencyCode: currencyCode, result: &result)
            case .owedToMe:
                migrateOwedEntry(entry, clientId: clientId, studioStore: studioStore, currencyCode: currencyCode, result: &result)
            case .advanceReceived, .lent:
                migrateNoteEntry(entry, clientId: clientId, studioStore: studioStore, currencyCode: currencyCode, result: &result)
            }
        }

        studioStore.save()
        return result
    }

    @MainActor
    private static func migrateJobEntry(
        _ entry: SimpleStudioEntry,
        clientId: UUID?,
        studioStore: StudioStore,
        currencyCode: String,
        result: inout SimpleStudioMigrationResult
    ) {
        if !studioStore.invoices.contains(where: { $0.id == entry.id }) && !entry.isJobFullyPaid {
            guard let clientId else { return }
            let label = entry.jobLabel ?? "Job"
            let invoiceTotal = entry.agreedPrice ?? entry.amount
            let lineItem = StudioInvoiceLineItem(description: label, quantity: 1, unitPrice: invoiceTotal)
            let invoice = StudioInvoice(
                id: entry.id,
                clientId: clientId,
                invoiceNumber: studioStore.nextInvoiceNumber(),
                issueDate: entry.createdAt,
                dueDate: entry.createdAt.addingTimeInterval(14 * 86400),
                status: .sent,
                currencyCode: currencyCode,
                lineItems: [lineItem],
                subtotal: invoiceTotal,
                taxAmount: 0,
                total: invoiceTotal,
                notes: entry.note ?? "Imported from Simple Studio.",
                externalReference: "simple-job"
            )
            studioStore.addInvoice(invoice)
            result.invoicesAdded += 1
        }

        if let clientId, !studioStore.projects.contains(where: { $0.id == entry.id }) {
            var project = StudioProject(
                id: entry.id,
                name: entry.jobLabel ?? "Job",
                clientId: clientId,
                startDate: entry.createdAt,
                fixedFee: entry.agreedPrice ?? entry.amount,
                notes: entry.note ?? "Imported from Simple Studio."
            )
            if entry.paymentStatus == .paid {
                project.endDate = entry.createdAt
            }
            studioStore.addProject(project)
            result.projectsAdded += 1
        }

        migrateJobCosts(entry, clientId: clientId, projectId: entry.id, studioStore: studioStore, currencyCode: currencyCode, result: &result)
    }

    @MainActor
    private static func migrateIncomeEntry(
        _ entry: SimpleStudioEntry,
        clientId: UUID?,
        studioStore: StudioStore,
        currencyCode: String,
        result: inout SimpleStudioMigrationResult
    ) {
        guard !studioStore.invoices.contains(where: { $0.id == entry.id }) else { return }
        guard let clientId else {
            migrateExpenseEntry(
                entry,
                clientId: nil,
                studioStore: studioStore,
                currencyCode: currencyCode,
                result: &result,
                asIncomeReceipt: true
            )
            return
        }

        let description = entry.jobLabel ?? entry.kind.logTitle
        let lineItem = StudioInvoiceLineItem(description: description, quantity: 1, unitPrice: entry.amount + (entry.tip ?? 0))
        let invoice = StudioInvoice(
            id: entry.id,
            clientId: clientId,
            invoiceNumber: studioStore.nextInvoiceNumber(),
            issueDate: entry.createdAt,
            dueDate: entry.createdAt,
            status: .paid,
            currencyCode: currencyCode,
            lineItems: [lineItem],
            subtotal: entry.amount + (entry.tip ?? 0),
            taxAmount: 0,
            total: entry.amount + (entry.tip ?? 0),
            notes: entry.note ?? "Imported from Simple Studio.",
            paymentDate: entry.createdAt,
            externalReference: "simple-income"
        )
        studioStore.addInvoice(invoice)
        result.invoicesAdded += 1

        migrateJobCosts(entry, clientId: clientId, projectId: nil, studioStore: studioStore, currencyCode: currencyCode, result: &result)
    }

    @MainActor
    private static func migrateOwedEntry(
        _ entry: SimpleStudioEntry,
        clientId: UUID?,
        studioStore: StudioStore,
        currencyCode: String,
        result: inout SimpleStudioMigrationResult
    ) {
        guard entry.paymentStatus != .paid else {
            migrateIncomeEntry(entry, clientId: clientId, studioStore: studioStore, currencyCode: currencyCode, result: &result)
            return
        }
        guard !studioStore.invoices.contains(where: { $0.id == entry.id }) else { return }
        guard let clientId else { return }

        let lineItem = StudioInvoiceLineItem(
            description: entry.jobLabel ?? "Balance owed",
            quantity: 1,
            unitPrice: entry.amount
        )
        let invoice = StudioInvoice(
            id: entry.id,
            clientId: clientId,
            invoiceNumber: studioStore.nextInvoiceNumber(),
            issueDate: entry.createdAt,
            dueDate: entry.createdAt.addingTimeInterval(14 * 86400),
            status: .sent,
            currencyCode: currencyCode,
            lineItems: [lineItem],
            subtotal: entry.amount,
            taxAmount: 0,
            total: entry.amount,
            notes: entry.note ?? "Imported from Simple Studio — waiting on payment.",
            externalReference: "simple-owed"
        )
        studioStore.addInvoice(invoice)
        result.invoicesAdded += 1
    }

    @MainActor
    private static func migrateExpenseEntry(
        _ entry: SimpleStudioEntry,
        clientId: UUID?,
        studioStore: StudioStore,
        currencyCode: String,
        result: inout SimpleStudioMigrationResult,
        asIncomeReceipt: Bool = false
    ) {
        guard !studioStore.receipts.contains(where: { $0.id == entry.id }) else { return }

        let merchant = entry.customerName.isEmpty
            ? (entry.jobLabel ?? entry.kind.logTitle)
            : entry.customerName
        let category = entry.kind == .iOwe ? "Accounts Payable" : "Business Expenses"
        let receipt = StudioReceipt(
            id: entry.id,
            date: entry.createdAt,
            amount: entry.amount,
            currencyCode: currencyCode,
            merchant: merchant,
            category: category,
            isDeductible: entry.kind != .iOwe,
            deductionStrength: entry.kind == .iOwe ? .weak : .medium,
            linkedClientId: clientId,
            localImagePath: entry.sourcePhotoPath,
            notes: [entry.note, asIncomeReceipt ? "Simple income (no customer)" : nil]
                .compactMap { $0 }
                .joined(separator: " · "),
            isBusiness: true
        )
        studioStore.addReceipt(receipt)
        result.receiptsAdded += 1
    }

    @MainActor
    private static func migrateJobCosts(
        _ entry: SimpleStudioEntry,
        clientId: UUID?,
        projectId: UUID?,
        studioStore: StudioStore,
        currencyCode: String,
        result: inout SimpleStudioMigrationResult
    ) {
        let costs: [(Decimal?, String, String)] = [
            (entry.materials, "Materials", "Materials"),
            (entry.petrol, "Petrol / Gas", "Vehicle & Travel"),
            (entry.transport, "Transport", "Vehicle & Travel"),
            (entry.platformFee, "Platform fee", "Business Expenses")
        ]

        for cost in costs {
            guard let amount = cost.0, amount > 0 else { continue }
            let alreadyLogged = studioStore.receipts.contains {
                $0.linkedProjectId == projectId
                    && $0.merchant == cost.1
                    && $0.amount == amount
                    && Calendar.current.isDate($0.date, inSameDayAs: entry.createdAt)
            }
            guard !alreadyLogged else { continue }

            let receipt = StudioReceipt(
                date: entry.createdAt,
                amount: amount,
                currencyCode: currencyCode,
                merchant: cost.1,
                category: cost.2,
                linkedClientId: clientId,
                linkedProjectId: projectId,
                localImagePath: entry.sourcePhotoPath,
                notes: "Job cost imported from Simple Studio.",
                isBusiness: true
            )
            studioStore.addReceipt(receipt)
            result.receiptsAdded += 1
        }
    }

    @MainActor
    private static func migrateNoteEntry(
        _ entry: SimpleStudioEntry,
        clientId: UUID?,
        studioStore: StudioStore,
        currencyCode: String,
        result: inout SimpleStudioMigrationResult
    ) {
        guard let clientId,
              let index = studioStore.clients.firstIndex(where: { $0.id == clientId }) else {
            migrateExpenseEntry(
                entry,
                clientId: clientId,
                studioStore: studioStore,
                currencyCode: currencyCode,
                result: &result
            )
            return
        }

        var client = studioStore.clients[index]
        let prefix = entry.kind == .advanceReceived ? "Advance" : "Loan"
        let line = "\(prefix): \(entry.amount) on \(BuxDisplayDate.monthDay(from: entry.createdAt, locale: BuxInterfaceLocale.currentInterfaceLocale))"
        client.notes = client.notes.isEmpty ? line : "\(client.notes)\n\(line)"
        studioStore.updateClient(client)
    }
}
