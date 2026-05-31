//
//  ProStudioSearchEngine.swift
//  BuxMuse
//
//  Offline Pro Studio search — clients, invoices, projects, receipts, mileage, and ledger.
//

import Foundation

enum ProStudioSearchEngine {

    enum Section: String, CaseIterable, Equatable {
        case clients = "Clients"
        case invoices = "Invoices"
        case projects = "Projects"
        case receipts = "Receipts"
        case mileage = "Mileage"
        case time = "Time"
        case ledger = "Ledger"
    }

    enum ResultKind: Equatable {
        case client(UUID)
        case invoice(UUID)
        case project(UUID)
        case receipt(UUID)
        case mileage(UUID)
        case timeEntry(projectId: UUID, entryId: UUID)
        case ledgerEntry(UUID)
        case ledgerInvoice(UUID)
        case ledgerPerson(UUID)
    }

    struct Result: Identifiable, Equatable {
        var id: UUID
        var kind: ResultKind
        var section: Section
        var title: String
        var subtitle: String
        var detail: String
        var amountFormatted: String?
        var matchReason: String
        var timestamp: Date
        var score: Int
    }

    struct QuickFilter: Identifiable, Equatable {
        var id: String
        var label: String
        var query: String
        var icon: String
    }

    static let quickFilters: [QuickFilter] = [
        QuickFilter(id: "overdue", label: "Overdue", query: "Overdue invoices", icon: "exclamationmark.circle"),
        QuickFilter(id: "draft", label: "Drafts", query: "Draft invoices", icon: "doc"),
        QuickFilter(id: "waiting", label: "Waiting", query: "Who owes me?", icon: "clock"),
        QuickFilter(id: "receipts", label: "Receipts", query: "Receipts this month", icon: "receipt"),
        QuickFilter(id: "mileage", label: "Mileage", query: "Mileage this month", icon: "car"),
        QuickFilter(id: "projects", label: "Projects", query: "Active projects", icon: "folder"),
        QuickFilter(id: "deductible", label: "Deductible", query: "Tax deductible expenses", icon: "percent")
    ]

    static let suggestionQueries = [
        "Overdue invoices",
        "Draft invoices",
        "Unpaid invoices this month",
        "Invoices sent not paid",
        "Receipts this week",
        "Tax deductible expenses",
        "Mileage this month",
        "Active projects",
        "Billable time this week",
        "Who owes me?",
        "Clients I work with",
        "Projects this month",
        "Receipts from Amazon",
        "Paid invoices last month",
        "Overdue over 30 days",
        "Income this month",
        "Expenses today",
        "Find a client",
        "Time logged today",
        "Business trips"
    ]

    struct ProIntentSet: OptionSet, Equatable {
        let rawValue: Int

        static let overdue = ProIntentSet(rawValue: 1 << 0)
        static let draft = ProIntentSet(rawValue: 1 << 1)
        static let unpaid = ProIntentSet(rawValue: 1 << 2)
        static let paid = ProIntentSet(rawValue: 1 << 3)
        static let clients = ProIntentSet(rawValue: 1 << 4)
        static let projects = ProIntentSet(rawValue: 1 << 5)
        static let receipts = ProIntentSet(rawValue: 1 << 6)
        static let mileage = ProIntentSet(rawValue: 1 << 7)
        static let deductible = ProIntentSet(rawValue: 1 << 8)
        static let time = ProIntentSet(rawValue: 1 << 9)
        static let active = ProIntentSet(rawValue: 1 << 10)
    }

    struct ParsedQuery: Equatable {
        var nameTokens: [String]
        var proIntents: ProIntentSet
        var simpleParsed: SimpleStudioSearchEngine.ParsedQuery
    }

    static func parse(_ rawQuery: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedQuery {
        let simpleParsed = SimpleStudioSearchEngine.parse(rawQuery, now: now, calendar: calendar)

        var working = rawQuery
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var proIntents = ProIntentSet()

        let phraseMap: [(phrases: [String], intents: ProIntentSet)] = [
            (["overdue", "past due", "late invoice", "late invoices"], [.overdue, .unpaid]),
            (["draft invoice", "draft invoices", "drafts"], [.draft]),
            (["sent not paid", "unpaid invoice", "unpaid invoices", "awaiting payment"], [.unpaid]),
            (["client", "clients", "customer", "customers"], [.clients]),
            (["project", "projects", "active project", "active projects"], [.projects, .active]),
            (["receipt", "receipts", "scanned receipt"], [.receipts]),
            (["mileage", "miles driven", "business trip", "business trips", "trips"], [.mileage]),
            (["deductible", "tax deductible", "write off", "write-off"], [.deductible, .receipts]),
            (["billable time", "time logged", "hours logged", "logged time"], [.time]),
            (["already paid", "paid invoice", "paid invoices"], [.paid])
        ]

        for rule in phraseMap {
            for phrase in rule.phrases where working.contains(phrase) {
                proIntents.formUnion(rule.intents)
                working = working.replacingOccurrences(of: phrase, with: " ")
            }
        }

        let stopWords: Set<String> = [
            "a", "an", "the", "for", "from", "with", "and", "or", "my", "me", "on", "in", "this", "that", "show", "find", "search", "over", "days"
        ]

        let proNameTokens = working
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 1 }

        let mergedNameTokens = simpleParsed.nameTokens.isEmpty ? proNameTokens : simpleParsed.nameTokens

        return ParsedQuery(
            nameTokens: mergedNameTokens,
            proIntents: proIntents,
            simpleParsed: simpleParsed
        )
    }

    static func search(
        query: String,
        studio: StudioSnapshot,
        simple: SimpleStudioSnapshot?,
        format: (Decimal) -> String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Result] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let parsed = parse(trimmed, now: now, calendar: calendar)
        var results: [Result] = []

        results.append(contentsOf: searchClients(parsed: parsed, clients: studio.clients, format: format))
        results.append(contentsOf: searchInvoices(
            parsed: parsed,
            invoices: studio.invoices,
            clients: studio.clients,
            format: format,
            now: now,
            calendar: calendar
        ))
        results.append(contentsOf: searchProjects(
            parsed: parsed,
            projects: studio.projects,
            clients: studio.clients,
            format: format,
            calendar: calendar
        ))
        results.append(contentsOf: searchReceipts(
            parsed: parsed,
            receipts: studio.receipts,
            format: format,
            calendar: calendar
        ))
        results.append(contentsOf: searchMileage(
            parsed: parsed,
            entries: studio.mileageEntries,
            calendar: calendar
        ))

        if let simple {
            let ledger = SimpleStudioSearchEngine.search(
                query: query,
                snapshot: simple,
                format: format,
                now: now,
                calendar: calendar
            )
            results.append(contentsOf: ledger.map { convertLedgerResult($0) })
        }

        var seen = Set<String>()
        return results
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.timestamp > $1.timestamp
            }
            .filter { result in
                let key = resultKey(result)
                return seen.insert(key).inserted
            }
    }

    static func groupedResults(_ results: [Result]) -> [(section: Section, items: [Result])] {
        Section.allCases.compactMap { section in
            let items = results.filter { $0.section == section }
            guard !items.isEmpty else { return nil }
            return (section, items)
        }
    }

    // MARK: - Private

    private static func convertLedgerResult(_ result: SimpleStudioSearchEngine.Result) -> Result {
        let kind: ResultKind
        switch result.kind {
        case .entry(let id): kind = .ledgerEntry(id)
        case .invoice(let id): kind = .ledgerInvoice(id)
        case .person(let id): kind = .ledgerPerson(id)
        }
        return Result(
            id: result.id,
            kind: kind,
            section: .ledger,
            title: result.title,
            subtitle: result.subtitle,
            detail: result.detail,
            amountFormatted: result.amountFormatted,
            matchReason: result.matchReason,
            timestamp: result.timestamp,
            score: max(result.score - 2, 1)
        )
    }

    private static func resultKey(_ result: Result) -> String {
        switch result.kind {
        case .client(let id): return "client-\(id)"
        case .invoice(let id): return "invoice-\(id)"
        case .project(let id): return "project-\(id)"
        case .receipt(let id): return "receipt-\(id)"
        case .mileage(let id): return "mileage-\(id)"
        case .timeEntry(_, let entryId): return "time-\(entryId)"
        case .ledgerEntry(let id): return "ledger-entry-\(id)"
        case .ledgerInvoice(let id): return "ledger-invoice-\(id)"
        case .ledgerPerson(let id): return "ledger-person-\(id)"
        }
    }

    private static func searchClients(
        parsed: ParsedQuery,
        clients: [StudioClient],
        format: (Decimal) -> String
    ) -> [Result] {
        clients.compactMap { client in
            let score = scoreClient(client, parsed: parsed)
            guard score > 0 else { return nil }

            var subtitleParts: [String] = []
            if !client.email.isEmpty { subtitleParts.append(client.email) }
            if !client.phone.isEmpty { subtitleParts.append(client.phone) }
            if !client.tags.isEmpty { subtitleParts.append(client.tags.joined(separator: ", ")) }

            return Result(
                id: client.id,
                kind: .client(client.id),
                section: .clients,
                title: client.name,
                subtitle: subtitleParts.joined(separator: " · "),
                detail: client.address,
                amountFormatted: client.defaultRate.map(format),
                matchReason: matchReason(for: parsed, fallback: "Client"),
                timestamp: Date(),
                score: score
            )
        }
    }

    private static func searchInvoices(
        parsed: ParsedQuery,
        invoices: [StudioInvoice],
        clients: [StudioClient],
        format: (Decimal) -> String,
        now: Date,
        calendar: Calendar
    ) -> [Result] {
        invoices.compactMap { invoice in
            guard passesDate(invoice.issueDate, parsed: parsed, calendar: calendar) else { return nil }
            guard passesInvoiceIntent(invoice, parsed: parsed, now: now) else { return nil }

            let score = scoreInvoice(invoice, clients: clients, parsed: parsed, now: now)
            guard score > 0 else { return nil }

            let clientName = clients.first { $0.id == invoice.clientId }?.name ?? "Client"
            return Result(
                id: invoice.id,
                kind: .invoice(invoice.id),
                section: .invoices,
                title: invoice.invoiceNumber.isEmpty ? "Invoice · \(clientName)" : invoice.invoiceNumber,
                subtitle: clientName,
                detail: invoice.status.rawValue,
                amountFormatted: format(invoice.total),
                matchReason: matchReason(for: parsed, fallback: "Invoice"),
                timestamp: invoice.issueDate,
                score: score
            )
        }
    }

    private static func searchProjects(
        parsed: ParsedQuery,
        projects: [StudioProject],
        clients: [StudioClient],
        format: (Decimal) -> String,
        calendar: Calendar
    ) -> [Result] {
        var results: [Result] = []

        for project in projects {
            guard passesDate(project.startDate, parsed: parsed, calendar: calendar) else { continue }
            if parsed.proIntents.contains(.active), let end = project.endDate, end < Date() { continue }

            let score = scoreProject(project, clients: clients, parsed: parsed)
            if score > 0 {
                let clientName = project.clientId.flatMap { id in clients.first { $0.id == id }?.name } ?? "No client"
                let amount = project.fixedFee ?? project.hourlyRate
                results.append(Result(
                    id: project.id,
                    kind: .project(project.id),
                    section: .projects,
                    title: project.name,
                    subtitle: clientName,
                    detail: "\(project.timeEntries.count) time entries",
                    amountFormatted: amount.map(format),
                    matchReason: matchReason(for: parsed, fallback: "Project"),
                    timestamp: project.startDate,
                    score: score
                ))
            }

            if parsed.proIntents.contains(.time) || !parsed.nameTokens.isEmpty {
                for entry in project.timeEntries {
                    guard passesDate(entry.startTime, parsed: parsed, calendar: calendar) else { continue }
                    let timeScore = scoreTimeEntry(entry, project: project, clients: clients, parsed: parsed)
                    guard timeScore > 0 else { continue }
                    results.append(Result(
                        id: entry.id,
                        kind: .timeEntry(projectId: project.id, entryId: entry.id),
                        section: .time,
                        title: project.name,
                        subtitle: entry.notes.isEmpty ? formattedDuration(entry.duration) : entry.notes,
                        detail: entry.isBillable ? "Billable" : "Non-billable",
                        amountFormatted: nil,
                        matchReason: "Time logged",
                        timestamp: entry.startTime,
                        score: timeScore
                    ))
                }
            }
        }

        return results
    }

    private static func searchReceipts(
        parsed: ParsedQuery,
        receipts: [StudioReceipt],
        format: (Decimal) -> String,
        calendar: Calendar
    ) -> [Result] {
        receipts.compactMap { receipt in
            guard passesDate(receipt.date, parsed: parsed, calendar: calendar) else { return nil }
            guard passesReceiptIntent(receipt, parsed: parsed) else { return nil }

            let score = scoreReceipt(receipt, parsed: parsed)
            guard score > 0 else { return nil }

            return Result(
                id: receipt.id,
                kind: .receipt(receipt.id),
                section: .receipts,
                title: receipt.merchant.isEmpty ? "Receipt" : receipt.merchant,
                subtitle: receipt.category,
                detail: receipt.isDeductible ? "Deductible" : receipt.businessUse.rawValue,
                amountFormatted: format(receipt.amount),
                matchReason: matchReason(for: parsed, fallback: "Receipt"),
                timestamp: receipt.date,
                score: score
            )
        }
    }

    private static func searchMileage(
        parsed: ParsedQuery,
        entries: [MileageEntry],
        calendar: Calendar
    ) -> [Result] {
        entries.compactMap { entry in
            guard passesDate(entry.date, parsed: parsed, calendar: calendar) else { return nil }
            let score = scoreMileage(entry, parsed: parsed)
            guard score > 0 else { return nil }

            let route = [entry.startLocation, entry.endLocation]
                .filter { !$0.isEmpty }
                .joined(separator: " → ")

            return Result(
                id: entry.id,
                kind: .mileage(entry.id),
                section: .mileage,
                title: route.isEmpty ? "Trip" : route,
                subtitle: entry.purpose.rawValue,
                detail: entry.notes,
                amountFormatted: String(format: "%.1f mi", entry.distance),
                matchReason: matchReason(for: parsed, fallback: "Mileage"),
                timestamp: entry.date,
                score: score
            )
        }
    }

    private static func scoreClient(_ client: StudioClient, parsed: ParsedQuery) -> Int {
        if parsed.proIntents.contains(.clients) && parsed.nameTokens.isEmpty { return 14 }

        var score = 0
        let haystack = [
            client.name,
            client.email,
            client.phone,
            client.address,
            client.notes,
            client.tags.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) {
            score += client.name.lowercased().contains(token) ? 24 : 10
        }

        if parsed.simpleParsed.intents.contains(.people) { score += 8 }
        if parsed.proIntents.contains(.clients) { score += 10 }
        if score == 0, parsed.proIntents.contains(.clients) { score = 6 }
        return score
    }

    private static func scoreInvoice(
        _ invoice: StudioInvoice,
        clients: [StudioClient],
        parsed: ParsedQuery,
        now: Date
    ) -> Int {
        var score = 0
        let clientName = clients.first { $0.id == invoice.clientId }?.name ?? ""
        let haystack = [
            invoice.invoiceNumber,
            clientName,
            invoice.notes,
            invoice.externalReference ?? ""
        ].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) { score += 14 }

        if parsed.proIntents.contains(.overdue), isOverdue(invoice, now: now) { score += 22 }
        if parsed.proIntents.contains(.draft), invoice.status == .draft { score += 20 }
        if parsed.proIntents.contains(.unpaid), !isPaid(invoice) { score += 18 }
        if parsed.proIntents.contains(.paid), isPaid(invoice) { score += 18 }
        if parsed.simpleParsed.intents.contains(.invoices) { score += 10 }
        if parsed.simpleParsed.intents.contains(.waitingOnMe), !isPaid(invoice) { score += 16 }
        if parsed.proIntents.isEmpty && parsed.simpleParsed.intents.isEmpty && parsed.nameTokens.isEmpty { return 0 }
        if score == 0, !parsed.proIntents.isEmpty || !parsed.simpleParsed.intents.isEmpty { score = 8 }
        return score
    }

    private static func scoreProject(_ project: StudioProject, clients: [StudioClient], parsed: ParsedQuery) -> Int {
        var score = 0
        let clientName = project.clientId.flatMap { id in clients.first { $0.id == id }?.name } ?? ""
        let haystack = [project.name, project.notes, clientName].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) { score += 14 }
        if parsed.proIntents.contains(.projects) { score += 12 }
        if parsed.proIntents.contains(.active) { score += 10 }
        if score == 0, parsed.proIntents.contains(.projects) { score = 6 }
        return score
    }

    private static func scoreTimeEntry(
        _ entry: StudioTimeEntry,
        project: StudioProject,
        clients: [StudioClient],
        parsed: ParsedQuery
    ) -> Int {
        var score = 0
        let clientName = project.clientId.flatMap { id in clients.first { $0.id == id }?.name } ?? ""
        let haystack = [project.name, entry.notes, clientName].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) { score += 12 }
        if parsed.proIntents.contains(.time) { score += 14 }
        return score
    }

    private static func scoreReceipt(_ receipt: StudioReceipt, parsed: ParsedQuery) -> Int {
        var score = 0
        let haystack = [receipt.merchant, receipt.category, receipt.notes].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) { score += 14 }
        if parsed.proIntents.contains(.receipts) { score += 14 }
        if parsed.proIntents.contains(.deductible), receipt.isDeductible { score += 18 }
        if parsed.simpleParsed.intents.contains(.expenses) { score += 10 }
        if score == 0, parsed.proIntents.contains(.receipts) { score = 6 }
        return score
    }

    private static func scoreMileage(_ entry: MileageEntry, parsed: ParsedQuery) -> Int {
        var score = 0
        let haystack = [
            entry.startLocation,
            entry.endLocation,
            entry.notes,
            entry.purpose.rawValue
        ].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) { score += 12 }
        if parsed.proIntents.contains(.mileage) { score += 16 }
        if score == 0, parsed.proIntents.contains(.mileage) { score = 6 }
        return score
    }

    private static func passesInvoiceIntent(_ invoice: StudioInvoice, parsed: ParsedQuery, now: Date) -> Bool {
        let hasProFilter = !parsed.proIntents.intersection([.overdue, .draft, .unpaid, .paid]).isEmpty

        if parsed.proIntents.contains(.overdue) {
            return isOverdue(invoice, now: now)
        }
        if parsed.proIntents.contains(.draft) {
            return invoice.status == .draft
        }
        if parsed.proIntents.contains(.unpaid) {
            return !isPaid(invoice)
        }
        if parsed.proIntents.contains(.paid) {
            return isPaid(invoice)
        }

        if parsed.simpleParsed.intents.contains(.waitingOnMe) {
            return !isPaid(invoice)
        }
        if parsed.simpleParsed.intents.contains(.paid) {
            return isPaid(invoice)
        }
        if parsed.simpleParsed.intents.contains(.unpaid) {
            return !isPaid(invoice)
        }
        if parsed.simpleParsed.intents.contains(.invoices) {
            return true
        }

        if hasProFilter { return false }
        if parsed.proIntents.isEmpty && parsed.simpleParsed.intents.isEmpty { return true }
        return parsed.nameTokens.isEmpty ? false : true
    }

    private static func passesReceiptIntent(_ receipt: StudioReceipt, parsed: ParsedQuery) -> Bool {
        if parsed.proIntents.isEmpty && parsed.simpleParsed.intents.isEmpty { return true }
        if parsed.proIntents.contains(.deductible) { return receipt.isDeductible }
        if parsed.proIntents.contains(.receipts) { return true }
        if parsed.simpleParsed.intents.contains(.expenses) { return true }
        return parsed.nameTokens.isEmpty ? false : true
    }

    private static func passesDate(_ date: Date, parsed: ParsedQuery, calendar: Calendar) -> Bool {
        guard let range = parsed.simpleParsed.dateRange else { return true }
        return range.contains(date)
    }

    private static func isPaid(_ invoice: StudioInvoice) -> Bool {
        invoice.status == .paid
    }

    private static func isOverdue(_ invoice: StudioInvoice, now: Date) -> Bool {
        if invoice.status == .overdue { return true }
        return invoice.status != .paid && invoice.dueDate < now
    }

    private static func formattedDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func matchReason(for parsed: ParsedQuery, fallback: String) -> String {
        if parsed.proIntents.contains(.overdue) { return "Overdue" }
        if parsed.proIntents.contains(.draft) { return "Draft" }
        if parsed.proIntents.contains(.unpaid) { return "Unpaid" }
        if parsed.proIntents.contains(.paid) { return "Paid" }
        if parsed.proIntents.contains(.deductible) { return "Deductible" }
        if parsed.proIntents.contains(.mileage) { return "Mileage" }
        if parsed.proIntents.contains(.receipts) { return "Receipt" }
        if parsed.proIntents.contains(.projects) { return "Project" }
        if parsed.proIntents.contains(.clients) { return "Client" }
        if parsed.proIntents.contains(.time) { return "Time logged" }
        if parsed.simpleParsed.intents.contains(.waitingOnMe) { return "Waiting on payment" }
        if parsed.simpleParsed.dateRange != nil { return "This period" }
        return fallback
    }
}
