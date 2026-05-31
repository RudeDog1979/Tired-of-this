//
//  SimpleStudioEngine.swift
//  BuxMuse
//
//  Pure calculations for Simple Studio hub displays.
//

import Foundation

enum SimpleStudioEngine {

    static func buildHubDisplay(
        snapshot: SimpleStudioSnapshot,
        businessTitle: String,
        persona: StudioPersona,
        format: (Decimal) -> String
    ) -> SimpleStudioHubDisplay {
        let calendar = Calendar.current
        let now = Date()
        let todayEntries = snapshot.entries.filter { calendar.isDateInToday($0.createdAt) }
        let monthEntries = snapshot.entries.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month)
        }

        let todayKept = todayEntries.reduce(Decimal(0)) { $0 + $1.netKept }
        let monthMade = sumMade(entries: monthEntries)
        let monthSpent = sumSpent(entries: monthEntries)
        let waiting = sumWaiting(snapshot: snapshot)
        let owe = sumIOwe(entries: snapshot.entries)

        return SimpleStudioHubDisplay(
            businessTitle: businessTitle.isEmpty ? "Your Work" : businessTitle,
            todayKeptFormatted: format(todayKept),
            madeFormatted: format(monthMade),
            spentFormatted: format(monthSpent),
            waitingFormatted: format(waiting),
            oweFormatted: format(owe),
            spentFootnote: spentFootnote(for: persona),
            waitingItems: buildWaitingItems(snapshot: snapshot, format: format),
            iOweItems: buildIOweItems(snapshot: snapshot, format: format),
            recentItems: buildRecentItems(snapshot: snapshot, format: format),
            monthChartSlices: buildMonthChartSlices(
                made: monthMade,
                spent: monthSpent,
                waiting: waiting,
                owe: owe,
                format: format
            ),
            taxTile: buildTaxTile(
                made: monthMade,
                spent: monthSpent,
                persona: persona,
                format: format
            ),
            isEmpty: snapshot.entries.isEmpty && snapshot.invoices.isEmpty
        )
    }

    static func buildMyMoneyDisplay(
        snapshot: SimpleStudioSnapshot,
        persona: StudioPersona,
        format: (Decimal) -> String
    ) -> SimpleMyMoneyDisplay {
        let calendar = Calendar.current
        let now = Date()
        let monthEntries = snapshot.entries.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month)
        }
        let monthMade = sumMade(entries: monthEntries)
        let monthSpent = sumSpent(entries: monthEntries)
        let waiting = sumWaiting(snapshot: snapshot)
        let owe = sumIOwe(entries: snapshot.entries)

        return SimpleMyMoneyDisplay(
            monthSlices: buildMonthChartSlices(
                made: monthMade,
                spent: monthSpent,
                waiting: waiting,
                owe: owe,
                format: format
            ),
            waitingItems: buildWaitingItems(snapshot: snapshot, format: format),
            iOweItems: buildIOweItems(snapshot: snapshot, format: format),
            jobPockets: buildJobPockets(entries: monthEntries, format: format),
            taxTile: buildTaxTile(made: monthMade, spent: monthSpent, persona: persona, format: format)
        )
    }

    static func sumMade(entries: [SimpleStudioEntry]) -> Decimal {
        entries.reduce(Decimal(0)) { partial, entry in
            switch entry.kind {
            case .income, .job, .repaymentReceived:
                return partial + entry.amount + (entry.tip ?? 0)
            case .owedToMe where entry.paymentStatus == .paid:
                return partial + entry.amount
            default:
                return partial
            }
        }
    }

    static func sumSpent(entries: [SimpleStudioEntry]) -> Decimal {
        entries.reduce(Decimal(0)) { partial, entry in
            switch entry.kind {
            case .expense, .iOwe, .lent:
                return partial + entry.amount
            case .job, .income:
                return partial + entry.jobCosts
            default:
                return partial
            }
        }
    }

    static func sumWaiting(snapshot: SimpleStudioSnapshot) -> Decimal {
        let entryWaiting = snapshot.entries.reduce(Decimal(0)) { partial, entry in
            switch entry.kind {
            case .job where !entry.isJobFullyPaid:
                return partial + entry.jobBalanceDue
            case .owedToMe where entry.paymentStatus != .paid:
                return partial + entry.amount
            default:
                return partial
            }
        }
        let invoiceWaiting = snapshot.invoices
            .filter { $0.status != .paid }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return entryWaiting + invoiceWaiting
    }

    static func sumIOwe(entries: [SimpleStudioEntry]) -> Decimal {
        entries
            .filter { $0.kind == .iOwe && $0.paymentStatus != .paid }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    static func buildWaitingItems(
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String
    ) -> [SimpleWaitingItem] {
        var items: [SimpleWaitingItem] = []

        for invoice in snapshot.invoices where invoice.status != .paid {
            items.append(SimpleWaitingItem(
                id: invoice.id,
                customerName: invoice.customerName,
                amount: invoice.amount,
                amountFormatted: format(invoice.amount),
                jobLabel: invoice.jobDescription,
                daysWaiting: daysSince(invoice.createdAt),
                advanceBalance: nil,
                advanceBalanceFormatted: nil
            ))
        }

        for entry in snapshot.entries where entry.kind == .owedToMe && entry.paymentStatus != .paid {
            items.append(waitingItem(for: entry, snapshot: snapshot, format: format))
        }

        for entry in snapshot.entries where entry.kind == .job && !entry.isJobFullyPaid {
            items.append(waitingItem(for: entry, snapshot: snapshot, format: format))
        }

        return items.sorted { $0.daysWaiting > $1.daysWaiting }
    }

    static func buildIOweItems(
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String
    ) -> [SimpleWaitingItem] {
        snapshot.entries
            .filter { ($0.kind == .iOwe || $0.kind == .lent) && $0.paymentStatus != .paid }
            .map { entry in
                SimpleWaitingItem(
                    id: entry.id,
                    customerName: entry.customerName.isEmpty ? "Someone" : entry.customerName,
                    amount: entry.amount,
                    amountFormatted: format(entry.amount),
                    jobLabel: entry.jobLabel ?? entry.kind.logTitle,
                    daysWaiting: daysSince(entry.createdAt),
                    advanceBalance: nil,
                    advanceBalanceFormatted: nil
                )
            }
            .sorted { $0.daysWaiting > $1.daysWaiting }
    }

    static func buildRecentItems(
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String,
        limit: Int = 8
    ) -> [SimpleRecentItem] {
        var rows: [SimpleRecentItem] = []

        for entry in snapshot.entries.sorted(by: { $0.createdAt > $1.createdAt }).prefix(limit) {
            let positive = entry.netKept >= 0
            rows.append(SimpleRecentItem(
                id: entry.id,
                title: recentTitle(for: entry),
                subtitle: recentSubtitle(for: entry),
                amountFormatted: format(abs(entry.netKept != 0 ? entry.netKept : entry.amount)),
                isPositive: positive,
                hasPhoto: entry.sourcePhotoPath != nil,
                photoPath: entry.sourcePhotoPath,
                timestamp: entry.createdAt
            ))
        }

        for invoice in snapshot.invoices.sorted(by: { $0.createdAt > $1.createdAt }).prefix(max(0, limit - rows.count)) {
            rows.append(SimpleRecentItem(
                id: invoice.id,
                title: "Invoice → \(invoice.customerName)",
                subtitle: invoice.status == .paid ? "Paid" : "Sent · waiting",
                amountFormatted: format(invoice.amount),
                isPositive: true,
                hasPhoto: false,
                photoPath: nil,
                timestamp: invoice.createdAt
            ))
        }

        return rows.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }

    static func waitingItem(
        for entry: SimpleStudioEntry,
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String
    ) -> SimpleWaitingItem {
        let due = entry.kind == .job ? entry.jobBalanceDue : entry.amount
        let advance = entry.advanceAmount ?? advanceBalance(for: entry, in: snapshot.entries)
        let label: String = {
            if entry.kind == .job, let agreed = entry.agreedPrice {
                return "\(entry.jobLabel ?? "Job") · agreed \(format(agreed))"
            }
            return entry.jobLabel ?? entry.kind.logTitle
        }()
        return SimpleWaitingItem(
            id: entry.id,
            customerName: entry.customerName.isEmpty ? "Someone" : entry.customerName,
            amount: due,
            amountFormatted: format(due),
            jobLabel: label,
            daysWaiting: daysSince(entry.createdAt),
            advanceBalance: advance > 0 ? advance : nil,
            advanceBalanceFormatted: advance > 0 ? format(advance) : nil
        )
    }

    static func buildJobPockets(
        entries: [SimpleStudioEntry],
        format: (Decimal) -> String
    ) -> [SimpleJobPocketDisplay] {
        entries
            .filter { $0.kind == .job }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .compactMap { job -> SimpleJobPocketDisplay? in
                guard let breakdown = job.jobBreakdown() else { return nil }
                let maxVal = max(
                    NSDecimalNumber(decimal: breakdown.agreed).doubleValue,
                    NSDecimalNumber(decimal: breakdown.paidSoFar).doubleValue,
                    1
                )
                return SimpleJobPocketDisplay(
                    id: job.id,
                    customerName: job.customerName.isEmpty ? "Customer" : job.customerName,
                    jobLabel: job.jobLabel ?? "Job",
                    agreedFormatted: format(breakdown.agreed),
                    paidFormatted: format(breakdown.paidSoFar),
                    spentFormatted: format(breakdown.spent),
                    waitingFormatted: format(breakdown.balanceDue),
                    keptFormatted: format(breakdown.keptSoFar),
                    projectedKeptFormatted: format(breakdown.projectedKept),
                    keptFraction: max(0, min(1, NSDecimalNumber(decimal: breakdown.keptSoFar).doubleValue / maxVal))
                )
            }
    }

    static func buildMonthChartSlices(
        made: Decimal,
        spent: Decimal,
        waiting: Decimal,
        owe: Decimal,
        format: (Decimal) -> String
    ) -> [SimpleChartSlice] {
        let total = made + spent + waiting + owe
        let totalDouble = max(NSDecimalNumber(decimal: total).doubleValue, 1)
        func slice(id: String, label: String, value: Decimal) -> SimpleChartSlice {
            SimpleChartSlice(
                id: id,
                label: label,
                value: value,
                valueFormatted: format(value),
                fraction: NSDecimalNumber(decimal: value).doubleValue / totalDouble
            )
        }
        return [
            slice(id: "made", label: "Made", value: made),
            slice(id: "spent", label: "Spent", value: spent),
            slice(id: "waiting", label: "Waiting", value: waiting),
            slice(id: "owe", label: "You owe", value: owe)
        ].filter { $0.value > 0 }
    }

    static func buildTaxTile(
        made: Decimal,
        spent: Decimal,
        persona: StudioPersona,
        format: (Decimal) -> String
    ) -> SimpleTaxTileDisplay {
        let keep = made - spent
        let mightOwe = max(0, keep * Decimal(0.15))
        return SimpleTaxTileDisplay(
            made: format(made),
            spent: format(spent),
            keep: format(keep),
            mightOwe: format(mightOwe),
            coachLine: coachLine(for: persona)
        )
    }

    static func advanceBalance(for entry: SimpleStudioEntry, in entries: [SimpleStudioEntry]) -> Decimal {
        let jobId = entry.linkedJobId ?? (entry.kind == .job ? entry.id : nil)
        guard let jobId else { return entry.advanceAmount ?? 0 }
        let advances = entries
            .filter { $0.linkedJobId == jobId || $0.id == jobId }
            .filter { $0.kind == .advanceReceived }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let materials = entries
            .filter { $0.linkedJobId == jobId || $0.id == jobId }
            .reduce(Decimal(0)) { $0 + ($1.materials ?? 0) + ($1.petrol ?? 0) + ($1.transport ?? 0) }
        return max(0, advances - materials)
    }

    static func daysSince(_ date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    static func spentFootnote(for persona: StudioPersona) -> String {
        switch persona {
        case .tasksAndGigs: return "fees + travel"
        case .jobsAndRepairs: return "materials + petrol"
        case .driving: return "fuel + costs"
        case .shop: return "stock + costs"
        case .lending: return "loans out"
        case .other: return "job costs"
        }
    }

    static func coachLine(for persona: StudioPersona) -> String {
        switch persona {
        case .tasksAndGigs:
            return "Many gig workers set aside a little from each job — this is just a guide."
        case .jobsAndRepairs:
            return "Track materials and petrol so you know what each job really paid."
        case .driving:
            return "Fuel adds up — logging trips keeps your real pay honest."
        case .shop:
            return "Know what came in and what went out each day."
        case .lending:
            return "Keep hand-to-hand loans clear — for you and them."
        case .other:
            return "Simple numbers help you plan — not official tax advice."
        }
    }

    static func recentTitle(for entry: SimpleStudioEntry) -> String {
        switch entry.kind {
        case .income: return "Income"
        case .expense: return "Expense"
        case .job: return entry.jobLabel ?? "Job"
        case .advanceReceived: return "Advance"
        case .owedToMe: return "Waiting on"
        case .iOwe: return "You owe"
        case .lent: return "Lent out"
        case .repaymentReceived: return "Repayment"
        }
    }

    static func recentSubtitle(for entry: SimpleStudioEntry) -> String {
        if !entry.customerName.isEmpty { return entry.customerName }
        return entry.note ?? entry.kind.logTitle
    }
}
