//
//  SimpleStudioSearchEngine.swift
//  BuxMuse
//
//  Offline natural-language search for Simple Studio — no network required.
//

import Foundation

enum SimpleStudioSearchEngine {

    struct ParsedQuery: Equatable {
        var remainingText: String
        var nameTokens: [String]
        var intents: IntentSet
        var dateRange: ClosedRange<Date>?
        var chartSliceID: String?
    }

    struct IntentSet: OptionSet, Equatable {
        let rawValue: Int

        static let waitingOnMe = IntentSet(rawValue: 1 << 0)
        static let iOwe = IntentSet(rawValue: 1 << 1)
        static let paid = IntentSet(rawValue: 1 << 2)
        static let unpaid = IntentSet(rawValue: 1 << 3)
        static let jobs = IntentSet(rawValue: 1 << 4)
        static let invoices = IntentSet(rawValue: 1 << 5)
        static let expenses = IntentSet(rawValue: 1 << 6)
        static let income = IntentSet(rawValue: 1 << 7)
        static let people = IntentSet(rawValue: 1 << 8)
    }

    enum ResultKind: Equatable {
        case entry(UUID)
        case invoice(UUID)
        case person(UUID)
    }

    struct Result: Identifiable, Equatable {
        var id: UUID
        var kind: ResultKind
        var title: String
        var subtitle: String
        var detail: String
        var amountFormatted: String?
        var matchReason: String
        var timestamp: Date
        var score: Int
    }

    static let simpleSuggestionQueries = [
        "Who owes me?",
        "Waiting on payment",
        "What do I owe?",
        "They owe me",
        "Jobs this month",
        "Invoices waiting",
        "Expenses this week",
        "Money in this month",
        "What did I spend?",
        "Paid this month",
        "Unpaid jobs",
        "People I work with",
        "Income last month",
        "Expenses today",
        "Find a customer",
        "Who paid me?",
        "Settled debts",
        "Work done this week"
    ]

    /// Backward-compatible alias used by tests.
    static let suggestionQueries = simpleSuggestionQueries

    static func parse(_ rawQuery: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedQuery {
        var working = rawQuery
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var intents = IntentSet()
        var chartSliceID: String?
        var dateRange: ClosedRange<Date>?

        let phraseMap: [(phrases: [String], intents: IntentSet, slice: String?)] = [
            (
                [
                    "who owes me", "owes me", "they owe me", "still waiting", "waiting on", "waiting for",
                    "unpaid", "not paid",
                    "quien me debe", "quién me debe", "me deben", "esperando pago", "esperando", "sin pagar", "no pagado"
                ],
                [.waitingOnMe, .unpaid], "waiting"
            ),
            (
                ["what do i owe", "i owe", "owe them", "debts i owe", "que debo", "qué debo", "debo", "les debo", "deudas"],
                [.iOwe], "owe"
            ),
            (
                ["paid", "settled", "already paid", "pagado", "saldado", "ya pago", "ya pagó"],
                [.paid], nil
            ),
            (["invoice", "invoices", "factura", "facturas"], [.invoices], nil),
            (["job", "jobs", "work done", "trabajo", "trabajos", "trabajo hecho"], [.jobs], nil),
            (
                ["expense", "expenses", "spent", "spending", "gasto", "gastos", "gaste", "gasté", "en que gaste"],
                [.expenses], "spent"
            ),
            (
                ["income", "earned", "money in", "made", "ingreso", "ingresos", "gane", "gané", "dinero entrante"],
                [.income], "made"
            ),
            (
                ["people", "person", "customer", "customers", "contact", "contacts",
                 "personas", "persona", "cliente", "clientes", "contacto", "contactos"],
                [.people], nil
            )
        ]

        for rule in phraseMap {
            for phrase in rule.phrases where working.contains(phrase) {
                intents.formUnion(rule.intents)
                if chartSliceID == nil { chartSliceID = rule.slice }
                working = working.replacingOccurrences(of: phrase, with: " ")
            }
        }

        let dateRules: [(phrases: [String], range: ClosedRange<Date>)] = [
            (["today", "hoy"], dayRange(for: now, calendar: calendar)),
            (["this week", "esta semana"], weekRange(containing: now, calendar: calendar)),
            (["this month", "este mes"], monthRange(containing: now, calendar: calendar)),
            (["last month", "mes pasado", "el mes pasado"], previousMonthRange(before: now, calendar: calendar))
        ]

        for rule in dateRules {
            for phrase in rule.phrases where working.contains(phrase) {
                dateRange = rule.range
                working = working.replacingOccurrences(of: phrase, with: " ")
            }
        }

        let stopWords: Set<String> = [
            "a", "an", "the", "for", "from", "with", "and", "or", "my", "me", "on", "in", "this", "that", "show", "find", "search",
            "el", "la", "los", "las", "de", "del", "y", "o", "mi", "en", "que", "esto", "esa", "buscar", "mostrar"
        ]

        let nameTokens = working
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 1 }

        return ParsedQuery(
            remainingText: working.trimmingCharacters(in: .whitespacesAndNewlines),
            nameTokens: nameTokens,
            intents: intents,
            dateRange: dateRange,
            chartSliceID: chartSliceID
        )
    }

    static func search(
        query: String,
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Result] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let parsed = parse(trimmed, now: now, calendar: calendar)
        var results: [Result] = []

        results.append(contentsOf: searchPeople(parsed: parsed, customers: snapshot.customers, format: format))
        results.append(contentsOf: searchInvoices(parsed: parsed, invoices: snapshot.invoices, format: format, calendar: calendar))
        results.append(contentsOf: searchEntries(parsed: parsed, entries: snapshot.entries, format: format, calendar: calendar))

        var seen = Set<UUID>()
        return results
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.timestamp > $1.timestamp
            }
            .filter { seen.insert($0.id).inserted }
    }

    static func entries(
        matchingChartSliceID sliceID: String,
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Result] {
        chartFilterResults(sliceID: sliceID, snapshot: snapshot, format: format, now: now, calendar: calendar)
    }

    static func chartFilterResults(
        sliceID: String,
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Result] {
        switch sliceID {
        case "waiting":
            var results: [Result] = []
            for invoice in snapshot.invoices where invoice.status != .paid {
                results.append(makeInvoiceResult(invoice, format: format, reason: "Waiting on payment"))
            }
            for entry in snapshot.entries {
                if entry.kind == .owedToMe, entry.paymentStatus != .paid {
                    results.append(makeEntryResult(entry, format: format, reason: "Waiting on payment"))
                } else if entry.kind == .job, !entryIsJobFullyPaid(entry) {
                    results.append(makeEntryResult(entry, format: format, reason: "Waiting on payment"))
                }
            }
            return sortedResults(results)

        case "owe":
            let entries = snapshot.entries.filter {
                ($0.kind == .iOwe || $0.kind == .lent) && $0.paymentStatus != .paid
            }
            return sortedResults(entries.map { makeEntryResult($0, format: format, reason: "You owe") })

        case "spent":
            let monthEntries = snapshot.entries.filter {
                calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month)
            }
            let filtered = monthEntries.filter(isSpentEntry)
            return sortedResults(filtered.map { makeEntryResult($0, format: format, reason: "Spent this month") })

        case "made":
            let monthEntries = snapshot.entries.filter {
                calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month)
            }
            let filtered = monthEntries.filter(isMadeEntry)
            return sortedResults(filtered.map { makeEntryResult($0, format: format, reason: "Made this month") })

        default:
            return []
        }
    }

    private nonisolated static func isSpentEntry(_ entry: SimpleStudioEntry) -> Bool {
        switch entry.kind {
        case .expense, .iOwe, .lent:
            return true
        case .job, .income:
            return entryJobCosts(entry) > 0 || entry.amount > 0
        default:
            return false
        }
    }

    private nonisolated static func isMadeEntry(_ entry: SimpleStudioEntry) -> Bool {
        switch entry.kind {
        case .income, .job, .repaymentReceived:
            return true
        case .owedToMe:
            return entry.paymentStatus == .paid
        default:
            return false
        }
    }

    private nonisolated static func entryJobCosts(_ entry: SimpleStudioEntry) -> Decimal {
        [entry.materials, entry.petrol, entry.transport, entry.platformFee].compactMap { $0 }.reduce(0, +)
    }

    private nonisolated static func entryIsJobFullyPaid(_ entry: SimpleStudioEntry) -> Bool {
        guard entry.kind == .job else { return entry.paymentStatus == .paid }
        if let agreed = entry.agreedPrice { return entry.amount >= agreed }
        return entry.paymentStatus == .paid
    }

    private nonisolated static func entryJobBalanceDue(_ entry: SimpleStudioEntry) -> Decimal {
        guard entry.kind == .job else { return 0 }
        if let agreed = entry.agreedPrice { return max(0, agreed - entry.amount) }
        return entry.paymentStatus == .paid ? 0 : entry.amount
    }

    private nonisolated static func entryIsPaidLikeWaiting(_ entry: SimpleStudioEntry) -> Bool {
        switch entry.kind {
        case .job: return entryIsJobFullyPaid(entry)
        case .owedToMe: return entry.paymentStatus == .paid
        default: return entry.paymentStatus == .paid
        }
    }

    private static func makeEntryResult(
        _ entry: SimpleStudioEntry,
        format: (Decimal) -> String,
        reason: String
    ) -> Result {
        let amount = entry.kind == .job ? entryJobBalanceDue(entry) : entry.amount
        return Result(
            id: entry.id,
            kind: .entry(entry.id),
            title: entryTitle(for: entry),
            subtitle: entry.customerName.isEmpty ? (entry.jobLabel ?? entry.kind.logTitle) : entry.customerName,
            detail: entry.jobLabel ?? entry.kind.logTitle,
            amountFormatted: format(amount),
            matchReason: reason,
            timestamp: entry.createdAt,
            score: 100
        )
    }

    private static func makeInvoiceResult(
        _ invoice: SimpleInvoice,
        format: (Decimal) -> String,
        reason: String
    ) -> Result {
        Result(
            id: invoice.id,
            kind: .invoice(invoice.id),
            title: "Invoice · \(invoice.customerName)",
            subtitle: invoice.jobDescription,
            detail: invoice.status == .paid ? "Paid" : "Waiting",
            amountFormatted: format(invoice.amount),
            matchReason: reason,
            timestamp: invoice.createdAt,
            score: 100
        )
    }

    private static func sortedResults(_ results: [Result]) -> [Result] {
        results.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Private

    private static func searchPeople(
        parsed: ParsedQuery,
        customers: [SimpleCustomerMemory],
        format: (Decimal) -> String
    ) -> [Result] {
        customers.compactMap { person in
            let score = scorePerson(person, parsed: parsed)
            guard score > 0 else { return nil }

            var subtitleParts: [String] = []
            if let job = person.lastJobLabel { subtitleParts.append("Last: \(job)") }
            if person.outstandingBalance > 0 {
                subtitleParts.append("Waiting \(format(person.outstandingBalance))")
            }

            return Result(
                id: person.id,
                kind: .person(person.id),
                title: person.name,
                subtitle: subtitleParts.joined(separator: " · "),
                detail: person.phone ?? "",
                amountFormatted: person.outstandingBalance > 0 ? format(person.outstandingBalance) : nil,
                matchReason: matchReason(for: parsed, fallback: "Person"),
                timestamp: person.lastSeen,
                score: score
            )
        }
    }

    private static func searchInvoices(
        parsed: ParsedQuery,
        invoices: [SimpleInvoice],
        format: (Decimal) -> String,
        calendar: Calendar
    ) -> [Result] {
        invoices.compactMap { invoice in
            guard passesDate(invoice.createdAt, parsed: parsed, calendar: calendar) else { return nil }
            let score = scoreInvoice(invoice, parsed: parsed)
            guard score > 0 else { return nil }

            return Result(
                id: invoice.id,
                kind: .invoice(invoice.id),
                title: "Invoice · \(invoice.customerName)",
                subtitle: invoice.jobDescription,
                detail: invoice.status == .paid ? "Paid" : "Waiting",
                amountFormatted: format(invoice.amount),
                matchReason: matchReason(for: parsed, fallback: "Invoice"),
                timestamp: invoice.createdAt,
                score: score
            )
        }
    }

    private static func searchEntries(
        parsed: ParsedQuery,
        entries: [SimpleStudioEntry],
        format: (Decimal) -> String,
        calendar: Calendar
    ) -> [Result] {
        entries.compactMap { entry in
            guard passesDate(entry.createdAt, parsed: parsed, calendar: calendar) else { return nil }
            guard passesIntent(entry, parsed: parsed) else { return nil }
            let score = scoreEntry(entry, parsed: parsed)
            guard score > 0 else { return nil }

            let amount = entry.kind == .job ? entryJobBalanceDue(entry) : entry.amount
            return Result(
                id: entry.id,
                kind: .entry(entry.id),
                title: entryTitle(for: entry),
                subtitle: entry.customerName.isEmpty ? (entry.jobLabel ?? entry.kind.logTitle) : entry.customerName,
                detail: entry.jobLabel ?? entry.kind.logTitle,
                amountFormatted: format(amount),
                matchReason: matchReason(for: parsed, fallback: entry.kind.logTitle),
                timestamp: entry.createdAt,
                score: score
            )
        }
    }

    private static func scorePerson(_ person: SimpleCustomerMemory, parsed: ParsedQuery) -> Int {
        if parsed.intents.contains(.people) && parsed.nameTokens.isEmpty { return 12 }

        var score = 0
        let haystack = [
            person.name,
            person.phone ?? "",
            person.notes ?? "",
            person.lastJobLabel ?? ""
        ].joined(separator: " ").lowercased()

        if parsed.nameTokens.isEmpty {
            return parsed.intents.contains(.waitingOnMe) && person.outstandingBalance > 0 ? 18 : 0
        }

        for token in parsed.nameTokens where haystack.contains(token) {
            score += person.name.lowercased().contains(token) ? 24 : 10
        }
        if parsed.intents.contains(.waitingOnMe), person.outstandingBalance > 0 { score += 8 }
        return score
    }

    private static func scoreInvoice(_ invoice: SimpleInvoice, parsed: ParsedQuery) -> Int {
        if parsed.intents.contains(.invoices) && parsed.nameTokens.isEmpty { return 14 }

        var score = 0
        let haystack = [
            invoice.customerName,
            invoice.jobDescription
        ].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) { score += 12 }

        if parsed.intents.contains(.waitingOnMe), invoice.status != .paid { score += 16 }
        if parsed.intents.contains(.paid), invoice.status == .paid { score += 16 }
        if parsed.intents.contains(.unpaid), invoice.status != .paid { score += 12 }
        if parsed.intents.isEmpty, parsed.nameTokens.isEmpty { score = 0 }
        if parsed.intents.contains(.invoices) { score += 8 }
        if score == 0, parsed.nameTokens.isEmpty, !parsed.intents.isEmpty { score = 6 }
        return score
    }

    private static func scoreEntry(_ entry: SimpleStudioEntry, parsed: ParsedQuery) -> Int {
        var score = 0
        let haystack = [
            entry.customerName,
            entry.jobLabel ?? "",
            entry.note ?? "",
            entry.kind.logTitle
        ].joined(separator: " ").lowercased()

        for token in parsed.nameTokens where haystack.contains(token) {
            if entry.customerName.lowercased().contains(token) { score += 20 }
            else if (entry.jobLabel ?? "").lowercased().contains(token) { score += 14 }
            else { score += 8 }
        }

        if parsed.intents.isEmpty && parsed.nameTokens.isEmpty { return 0 }
        if parsed.nameTokens.isEmpty && !parsed.intents.isEmpty { score += 10 }
        return score
    }

    private static func passesIntent(_ entry: SimpleStudioEntry, parsed: ParsedQuery) -> Bool {
        if parsed.intents.isEmpty { return true }

        var ok = false
        if parsed.intents.contains(.waitingOnMe) {
            ok = ok || ((entry.kind == .owedToMe || entry.kind == .job) && !entryIsPaidLikeWaiting(entry))
        }
        if parsed.intents.contains(.iOwe) {
            ok = ok || (entry.kind == .iOwe || entry.kind == .lent)
        }
        if parsed.intents.contains(.paid) {
            ok = ok || entry.paymentStatus == .paid || entryIsJobFullyPaid(entry)
        }
        if parsed.intents.contains(.unpaid) {
            ok = ok || entry.paymentStatus != .paid || !entryIsJobFullyPaid(entry)
        }
        if parsed.intents.contains(.jobs) {
            ok = ok || entry.kind == .job
        }
        if parsed.intents.contains(.expenses) {
            ok = ok || entry.kind == .expense || entry.kind == .iOwe
        }
        if parsed.intents.contains(.income) {
            ok = ok || entry.kind == .income || entry.kind == .job || entry.kind == .repaymentReceived
        }
        if parsed.intents.contains(.invoices) {
            ok = false
        }
        return ok
    }

    private static func passesDate(_ date: Date, parsed: ParsedQuery, calendar: Calendar) -> Bool {
        guard let range = parsed.dateRange else { return true }
        return range.contains(date)
    }

    private static func entryTitle(for entry: SimpleStudioEntry) -> String {
        if let job = entry.jobLabel, !job.isEmpty { return job }
        return entry.kind.logTitle
    }

    private static func matchReason(for parsed: ParsedQuery, fallback: String) -> String {
        if parsed.intents.contains(.waitingOnMe) { return "Waiting on payment" }
        if parsed.intents.contains(.iOwe) { return "You owe" }
        if parsed.intents.contains(.jobs) { return "Job" }
        if parsed.intents.contains(.invoices) { return "Invoice" }
        if parsed.intents.contains(.expenses) { return "Spent" }
        if parsed.intents.contains(.income) { return "Made" }
        if parsed.intents.contains(.people) { return "Person" }
        if parsed.dateRange != nil { return "This period" }
        return fallback
    }

    private static func dayRange(for date: Date, calendar: Calendar) -> ClosedRange<Date> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
        return start...end
    }

    private static func weekRange(containing date: Date, calendar: Calendar) -> ClosedRange<Date> {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start).map { $0.addingTimeInterval(-1) } ?? date
        return start...end
    }

    private static func monthRange(containing date: Date, calendar: Calendar) -> ClosedRange<Date> {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start).map { $0.addingTimeInterval(-1) } ?? date
        return start...end
    }

    private static func previousMonthRange(before date: Date, calendar: Calendar) -> ClosedRange<Date> {
        let thisMonthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? date
        let end = thisMonthStart.addingTimeInterval(-1)
        return start...end
    }
}
