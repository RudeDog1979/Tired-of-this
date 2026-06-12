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
        period: DateInterval,
        periodTitle: String,
        periodRangeSubtitle: String? = nil,
        format: (Decimal) -> String,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale,
        envelopeContext: TaxEnvelopeSourceContext? = nil
    ) -> SimpleStudioHubDisplay {
        let calendar = Calendar.current
        let todayEntries = snapshot.entries.filter { calendar.isDateInToday($0.createdAt) }
        let periodEntries = entries(in: period, from: snapshot.entries)

        let todayKept = todayEntries.reduce(Decimal(0)) { $0 + $1.netKept }
        let monthMade = sumMade(entries: periodEntries)
        let monthSpent = sumSpent(entries: periodEntries)
        let waiting = sumWaiting(snapshot: snapshot)
        let owe = sumIOwe(entries: snapshot.entries)

        return SimpleStudioHubDisplay(
            businessTitle: businessTitle.isEmpty
                ? SimpleStudioCopy.line("Your Work", locale: locale)
                : businessTitle,
            periodTitle: periodTitle,
            periodRangeSubtitle: periodRangeSubtitle,
            todayKeptFormatted: format(todayKept),
            madeFormatted: format(monthMade),
            spentFormatted: format(monthSpent),
            waitingFormatted: format(waiting),
            oweFormatted: format(owe),
            spentFootnote: spentFootnote(for: persona, locale: locale),
            waitingItems: buildWaitingItems(snapshot: snapshot, format: format, locale: locale),
            iOweItems: buildIOweItems(snapshot: snapshot, format: format, locale: locale),
            recentItems: buildRecentItems(snapshot: snapshot, format: format, locale: locale),
            monthChartSlices: buildMonthChartSlices(
                made: monthMade,
                spent: monthSpent,
                waiting: waiting,
                owe: owe,
                format: format,
                locale: locale
            ),
            taxTile: buildTaxTile(
                made: monthMade,
                spent: monthSpent,
                persona: persona,
                format: format,
                locale: locale,
                envelopeContext: envelopeContext
            ),
            isEmpty: snapshot.entries.isEmpty && snapshot.invoices.isEmpty
        )
    }

    static func buildMyMoneyDisplay(
        snapshot: SimpleStudioSnapshot,
        persona: StudioPersona,
        period: DateInterval,
        periodTitle: String,
        format: (Decimal) -> String,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale,
        envelopeContext: TaxEnvelopeSourceContext? = nil
    ) -> SimpleMyMoneyDisplay {
        let periodEntries = entries(in: period, from: snapshot.entries)
        let monthMade = sumMade(entries: periodEntries)
        let monthSpent = sumSpent(entries: periodEntries)
        let waiting = sumWaiting(snapshot: snapshot)
        let owe = sumIOwe(entries: snapshot.entries)

        return SimpleMyMoneyDisplay(
            periodTitle: periodTitle,
            monthSlices: buildMonthChartSlices(
                made: monthMade,
                spent: monthSpent,
                waiting: waiting,
                owe: owe,
                format: format,
                locale: locale
            ),
            waitingItems: buildWaitingItems(snapshot: snapshot, format: format, locale: locale),
            iOweItems: buildIOweItems(snapshot: snapshot, format: format, locale: locale),
            jobPockets: buildJobPockets(entries: periodEntries, format: format, locale: locale),
            taxTile: buildTaxTile(
                made: monthMade,
                spent: monthSpent,
                persona: persona,
                format: format,
                locale: locale,
                envelopeContext: envelopeContext
            )
        )
    }

    static func entries(in period: DateInterval, from entries: [SimpleStudioEntry]) -> [SimpleStudioEntry] {
        entries.filter { $0.createdAt >= period.start && $0.createdAt < period.end }
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
        format: (Decimal) -> String,
        locale: Locale
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
            items.append(waitingItem(for: entry, snapshot: snapshot, format: format, locale: locale))
        }

        for entry in snapshot.entries where entry.kind == .job && !entry.isJobFullyPaid {
            items.append(waitingItem(for: entry, snapshot: snapshot, format: format, locale: locale))
        }

        return items.sorted { $0.daysWaiting > $1.daysWaiting }
    }

    static func buildIOweItems(
        snapshot: SimpleStudioSnapshot,
        format: (Decimal) -> String,
        locale: Locale
    ) -> [SimpleWaitingItem] {
        snapshot.entries
            .filter { ($0.kind == .iOwe || $0.kind == .lent) && $0.paymentStatus != .paid }
            .map { entry in
                SimpleWaitingItem(
                    id: entry.id,
                    customerName: entry.customerName.isEmpty
                        ? SimpleStudioCopy.line("Someone", locale: locale)
                        : entry.customerName,
                    amount: entry.amount,
                    amountFormatted: format(entry.amount),
                    jobLabel: entry.jobLabel ?? entry.kind.localizedLogTitle(locale: locale),
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
        locale: Locale,
        limit: Int = 8
    ) -> [SimpleRecentItem] {
        var rows: [SimpleRecentItem] = []

        for entry in snapshot.entries.sorted(by: { $0.createdAt > $1.createdAt }).prefix(limit) {
            let positive = entry.netKept >= 0
            rows.append(SimpleRecentItem(
                id: entry.id,
                title: recentTitle(for: entry, locale: locale),
                subtitle: recentSubtitle(for: entry, locale: locale),
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
                title: SimpleStudioCopy.format("Invoice → %@", locale: locale, invoice.customerName),
                subtitle: invoice.status == .paid
                    ? SimpleStudioCopy.line("Paid", locale: locale)
                    : SimpleStudioCopy.line("Sent · waiting", locale: locale),
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
        format: (Decimal) -> String,
        locale: Locale
    ) -> SimpleWaitingItem {
        let due = entry.kind == .job ? entry.jobBalanceDue : entry.amount
        let advance = entry.advanceAmount ?? advanceBalance(for: entry, in: snapshot.entries)
        let label: String = {
            if entry.kind == .job, let agreed = entry.agreedPrice {
                return SimpleStudioCopy.format(
                    "%@ · agreed %@",
                    locale: locale,
                    entry.jobLabel ?? SimpleStudioCopy.line("Job", locale: locale),
                    format(agreed)
                )
            }
            return entry.jobLabel ?? entry.kind.localizedLogTitle(locale: locale)
        }()
        return SimpleWaitingItem(
            id: entry.id,
            customerName: entry.customerName.isEmpty
                ? SimpleStudioCopy.line("Someone", locale: locale)
                : entry.customerName,
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
        format: (Decimal) -> String,
        locale: Locale
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
                    customerName: job.customerName.isEmpty
                        ? SimpleStudioCopy.line("Customer", locale: locale)
                        : job.customerName,
                    jobLabel: job.jobLabel ?? SimpleStudioCopy.line("Job", locale: locale),
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
        format: (Decimal) -> String,
        locale: Locale
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
            slice(id: "made", label: SimpleStudioCopy.line("Made", locale: locale), value: made),
            slice(id: "spent", label: SimpleStudioCopy.line("Spent", locale: locale), value: spent),
            slice(id: "waiting", label: SimpleStudioCopy.line("Waiting", locale: locale), value: waiting),
            slice(id: "owe", label: SimpleStudioCopy.line("You owe", locale: locale), value: owe)
        ].filter { $0.value > 0 }
    }

    static func buildTaxTile(
        made: Decimal,
        spent: Decimal,
        persona: StudioPersona,
        format: (Decimal) -> String,
        locale: Locale,
        envelopeContext: TaxEnvelopeSourceContext? = nil
    ) -> SimpleTaxTileDisplay {
        let keep = made - spent
        let mightOwe = TaxEnvelopeEngine.taxTileMightOwe(
            made: made,
            spent: spent,
            context: envelopeContext
        )
        let coach = envelopeContext?.envelope.isEnabled == true
            ? TaxEnvelopeEngine.taxTileCoachLine(context: envelopeContext, persona: persona, locale: locale)
            : legacyCoachLine(for: persona, locale: locale)
        return SimpleTaxTileDisplay(
            made: format(made),
            spent: format(spent),
            keep: format(keep),
            mightOwe: format(mightOwe),
            coachLine: coach
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

    static func spentFootnote(for persona: StudioPersona, locale: Locale) -> String {
        switch persona {
        case .tasksAndGigs: return SimpleStudioCopy.line("fees + travel", locale: locale)
        case .jobsAndRepairs: return SimpleStudioCopy.line("materials + petrol", locale: locale)
        case .driving: return SimpleStudioCopy.line("fuel + costs", locale: locale)
        case .shop: return SimpleStudioCopy.line("stock + costs", locale: locale)
        case .lending: return SimpleStudioCopy.line("loans out", locale: locale)
        case .other: return SimpleStudioCopy.line("job costs", locale: locale)
        }
    }

    static func legacyCoachLine(for persona: StudioPersona, locale: Locale) -> String {
        switch persona {
        case .tasksAndGigs:
            return SimpleStudioCopy.line(
                "Many gig workers set aside a little from each job — this is just a guide.",
                locale: locale
            )
        case .jobsAndRepairs:
            return SimpleStudioCopy.line(
                "Track materials and petrol so you know what each job really paid.",
                locale: locale
            )
        case .driving:
            return SimpleStudioCopy.line(
                "Fuel adds up — logging trips keeps your real pay honest.",
                locale: locale
            )
        case .shop:
            return SimpleStudioCopy.line(
                "Know what came in and what went out each day.",
                locale: locale
            )
        case .lending:
            return SimpleStudioCopy.line(
                "Keep hand-to-hand loans clear — for you and them.",
                locale: locale
            )
        case .other:
            return SimpleStudioCopy.line(
                "Simple numbers help you plan — not official tax advice.",
                locale: locale
            )
        }
    }

    static func recentTitle(for entry: SimpleStudioEntry, locale: Locale) -> String {
        switch entry.kind {
        case .income: return SimpleStudioCopy.line("Income", locale: locale)
        case .expense: return SimpleStudioCopy.line("Expense", locale: locale)
        case .job: return entry.jobLabel ?? SimpleStudioCopy.line("Job", locale: locale)
        case .advanceReceived: return SimpleStudioCopy.line("Advance", locale: locale)
        case .owedToMe: return SimpleStudioCopy.line("Waiting on", locale: locale)
        case .iOwe: return SimpleStudioCopy.line("You owe", locale: locale)
        case .lent: return SimpleStudioCopy.line("Lent out", locale: locale)
        case .repaymentReceived: return SimpleStudioCopy.line("Repayment", locale: locale)
        }
    }

    static func recentSubtitle(for entry: SimpleStudioEntry, locale: Locale) -> String {
        if !entry.customerName.isEmpty { return entry.customerName }
        return entry.note ?? entry.kind.localizedLogTitle(locale: locale)
    }
}
