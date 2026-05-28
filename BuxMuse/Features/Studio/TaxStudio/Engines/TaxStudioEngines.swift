//
//  TaxStudioEngines.swift
//  BuxMuse
//
//  Local-first Tax Studio engines — deterministic, no network.
//

import Foundation

// MARK: - Tax Intelligence Engine

public enum TaxIntelligenceEngine {
    public static func compute(_ ctx: TaxStudioContext) -> TaxIntelligenceSnapshot {
        let mileageRate = SettingsStore.shared.mileageRatePerUnit
        let breakdown = StudioIncomeTaxEngine.compute(
            invoices: ctx.invoices,
            receipts: ctx.receipts,
            taxProfile: ctx.taxProfile,
            mileageEntries: ctx.mileageEntries,
            mileageRatePerUnit: mileageRate
        )
        let simulation = StudioTaxEngine.computeEstimatedTax(
            profile: ctx.profile,
            taxProfile: ctx.taxProfile,
            invoices: ctx.invoices,
            receipts: ctx.receipts,
            mileageEntries: ctx.mileageEntries,
            mileageRatePerUnit: mileageRate
        )
        let quarterly = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: ctx.invoices,
            receipts: ctx.receipts,
            taxProfile: ctx.taxProfile,
            mileageEntries: ctx.mileageEntries,
            mileageRatePerUnit: mileageRate,
            taxYearStartMonth: ctx.profile.taxYearStartMonth,
            now: ctx.now
        )

        let combinedRate = ((ctx.taxProfile.estimatedIncomeTaxRatePercent ?? 0)
            + (ctx.taxProfile.estimatedSelfEmployedRatePercent ?? 0)) / 100
        let deductibleSavings = breakdown.deductibleExpenses * combinedRate
        let social = breakdown.selfEmployedTax

        let (bracketLabel, proximity) = bracketProximity(
            taxable: breakdown.taxableIncome,
            rules: ctx.taxProfile.incomeTaxRules
        )
        let warnings = thresholdWarnings(ctx: ctx, breakdown: breakdown)

        return TaxIntelligenceSnapshot(
            breakdown: breakdown,
            taxSimulation: simulation,
            quarterly: quarterly,
            deductibleSavings: deductibleSavings,
            socialContributions: social,
            bracketLabel: bracketLabel,
            bracketProximityPercent: proximity,
            thresholdWarnings: warnings
        )
    }

    private static func bracketProximity(taxable: Decimal, rules: [TaxBracketRule]) -> (String, Int) {
        guard !rules.isEmpty else {
            let thresholds: [(Decimal, String)] = [
                (10_000, "£10k"),
                (50_000, "£50k"),
                (100_000, "£100k")
            ]
            for (limit, label) in thresholds where taxable < limit {
                let pct = taxable > 0
                    ? Int(truncating: ((taxable / limit) * 100) as NSDecimalNumber)
                    : 0
                return ("Approaching \(label) taxable band", min(99, pct))
            }
            return ("Highest heuristic band", 100)
        }
        let sorted = rules.sorted { $0.lowerBound < $1.lowerBound }
        for rule in sorted where taxable < rule.lowerBound {
            let pct = rule.lowerBound > 0
                ? Int(truncating: ((taxable / rule.lowerBound) * 100) as NSDecimalNumber)
                : 0
            return ("Approaching \(rule.lowerBound) threshold", min(99, pct))
        }
        return ("Top bracket in profile", 100)
    }

    private static func thresholdWarnings(ctx: TaxStudioContext, breakdown: IncomeTaxBreakdown) -> [String] {
        var items: [String] = []
        let rollingGross = rollingTwelveMonthGross(invoices: ctx.invoices, now: ctx.now)
        if !ctx.taxProfile.vatRegistered, rollingGross >= 85_000 {
            items.append("Rolling 12-month turnover may approach VAT/GST registration thresholds — review local rules.")
        }
        if breakdown.taxableIncome > 0,
           ctx.taxProfile.estimatedIncomeTaxRatePercent == nil,
           ctx.taxProfile.estimatedSelfEmployedRatePercent == nil {
            items.append("Set effective tax rates in Tax Studio Settings for accurate estimates.")
        }
        return items
    }

    static func rollingTwelveMonthGross(invoices: [StudioInvoice], now: Date) -> Decimal {
        let start = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        return invoices
            .filter { ($0.status == .paid || $0.status == .sent || $0.status == .overdue) && $0.issueDate >= start }
            .reduce(0) { $0 + $1.subtotal }
    }
}

// MARK: - Tax Forecasting Engine

public enum TaxForecastingEngine {
    public static func compute(_ ctx: TaxStudioContext, intelligence: TaxIntelligenceSnapshot) -> TaxForecastSnapshot {
        let calendar = Calendar.current
        let months = 12
        let incomeVelocity = monthlyVelocity(
            invoices: ctx.invoices,
            monthsBack: 6,
            now: ctx.now,
            calendar: calendar
        ) { $0.subtotal }
        let expenseVelocity = monthlyVelocity(
            receipts: ctx.receipts,
            monthsBack: 6,
            now: ctx.now,
            calendar: calendar
        ) { $0.amount }

        let seasonality = seasonalityFactor(for: ctx.now, calendar: calendar)
        let projectedAnnualIncome = incomeVelocity * Decimal(months) * seasonality
        let projectedAnnualDeductions = expenseVelocity * Decimal(months) * Decimal(0.85)
        let projectedTaxable = max(0, projectedAnnualIncome - projectedAnnualDeductions)

        let incomeRate = (ctx.taxProfile.estimatedIncomeTaxRatePercent ?? 0) / 100
        let seRate = (ctx.taxProfile.estimatedSelfEmployedRatePercent ?? 0) / 100
        let projectedTax = projectedTaxable * (incomeRate + seRate)
        let projectedQuarterly = projectedTax / 4
        let effective = projectedAnnualIncome > 0
            ? Double(truncating: (projectedTax / projectedAnnualIncome) as NSDecimalNumber)
            : 0

        let forecast = StudioCashflowEngine.computeForecast(
            invoices: ctx.invoices,
            receipts: ctx.receipts,
            estimatedTax: projectedTax
        )
        let netAfterTax = max(0, projectedAnnualIncome - projectedTax - projectedAnnualDeductions)
        let runway = expenseVelocity > 0
            ? Double(truncating: (netAfterTax / (expenseVelocity * 12)) as NSDecimalNumber)
            : forecast.runwayMonths

        let vatETA: Date? = {
            guard !ctx.taxProfile.vatRegistered, incomeVelocity > 0 else { return nil }
            let target: Decimal = 85_000
            let current = TaxIntelligenceEngine.rollingTwelveMonthGross(invoices: ctx.invoices, now: ctx.now)
            let remaining = max(0, target - current)
            let monthsToThreshold = remaining / incomeVelocity
            if monthsToThreshold <= 0 { return ctx.now }
            return calendar.date(byAdding: .month, value: Int(truncating: monthsToThreshold as NSDecimalNumber), to: ctx.now)
        }()

        return TaxForecastSnapshot(
            projectedTaxableIncome: projectedTaxable,
            projectedTaxOwed: projectedTax,
            projectedQuarterlyPayment: projectedQuarterly,
            projectedEffectiveRate: effective,
            projectedRunwayAfterTaxMonths: min(24, max(0, runway)),
            vatRegistrationETA: vatETA,
            bracketChangeMonthLabel: effective > intelligence.breakdown.effectiveRate ? "Q3–Q4" : nil,
            monthlyIncomeVelocity: incomeVelocity,
            monthlyExpenseVelocity: expenseVelocity
        )
    }

    private static func seasonalityFactor(for now: Date, calendar: Calendar) -> Decimal {
        let month = calendar.component(.month, from: now)
        switch month {
        case 11, 12: return Decimal(1.08)
        case 1, 2: return Decimal(0.92)
        default: return Decimal(1.0)
        }
    }

    private static func monthlyVelocity(
        invoices: [StudioInvoice],
        monthsBack: Int,
        now: Date,
        calendar: Calendar,
        amount: (StudioInvoice) -> Decimal
    ) -> Decimal {
        guard let start = calendar.date(byAdding: .month, value: -monthsBack, to: now) else { return 0 }
        let filtered = invoices.filter {
            ($0.status == .paid || $0.status == .sent) && $0.issueDate >= start
        }
        let total = filtered.reduce(0) { $0 + amount($1) }
        return monthsBack > 0 ? total / Decimal(monthsBack) : 0
    }

    private static func monthlyVelocity(
        receipts: [StudioReceipt],
        monthsBack: Int,
        now: Date,
        calendar: Calendar,
        amount: (StudioReceipt) -> Decimal
    ) -> Decimal {
        guard let start = calendar.date(byAdding: .month, value: -monthsBack, to: now) else { return 0 }
        let filtered = receipts.filter { $0.date >= start }
        let total = filtered.reduce(0) { $0 + amount($1) }
        return monthsBack > 0 ? total / Decimal(monthsBack) : 0
    }
}

// MARK: - Tax Health Score Engine

public enum TaxHealthScoreEngine {
    public static func compute(
        _ ctx: TaxStudioContext,
        intelligence: TaxIntelligenceSnapshot,
        sanity: TaxSanitySnapshot
    ) -> TaxHealthSnapshot {
        var score = 100
        var recs: [TaxHealthRecommendation] = []

        let categorized = ctx.receipts.filter { !$0.category.trimmingCharacters(in: .whitespaces).isEmpty }
        let catRatio = ctx.receipts.isEmpty ? 1.0 : Double(categorized.count) / Double(ctx.receipts.count)
        if catRatio < 0.7 {
            score -= 15
            recs.append(.init(
                id: "cat",
                title: "Categorize expenses",
                detail: "Tag receipts with business categories to maximize defensible deductions.",
                band: .yellow
            ))
        }

        let deductions = StudioDeductionEngine.computeDeductions(
            receipts: ctx.receipts,
            taxProfile: ctx.taxProfile,
            mileageEntries: ctx.mileageEntries,
            mileageRatePerUnit: SettingsStore.shared.mileageRatePerUnit
        )
        if !deductions.opportunities.isEmpty {
            score -= 10
            recs.append(.init(
                id: "ded",
                title: "Deduction opportunities",
                detail: "Review suggested deductions in Studio receipts.",
                band: .yellow
            ))
        }

        let missingImages = ctx.receipts.filter { ($0.localImagePath ?? "").isEmpty }.count
        if !ctx.receipts.isEmpty, missingImages > ctx.receipts.count / 3 {
            score -= 12
            recs.append(.init(
                id: "rcpt",
                title: "Attach receipts",
                detail: "Missing receipt images weaken audit readiness.",
                band: .yellow
            ))
        }

        if intelligence.quarterly.totalDue > 0,
           ctx.taxProfile.paymentSchedule == "quarterly",
           intelligence.quarterly.nextPaymentDate != nil {
            score -= 0
        } else if ctx.taxProfile.paymentSchedule == "quarterly" {
            score -= 8
        }

        if !ctx.taxProfile.vatRegistered,
           TaxIntelligenceEngine.rollingTwelveMonthGross(invoices: ctx.invoices, now: ctx.now) > 70_000 {
            score -= 10
            recs.append(.init(
                id: "vat",
                title: "VAT/GST threshold",
                detail: "Turnover is approaching common registration thresholds.",
                band: .red
            ))
        }

        if ctx.taxProfile.estimatedIncomeTaxRatePercent == nil && ctx.taxProfile.estimatedSelfEmployedRatePercent == nil {
            score -= 20
            recs.append(.init(
                id: "rates",
                title: "Set effective rates",
                detail: "Add income and self-employed % overrides in Tax Studio Settings.",
                band: .red
            ))
        }

        if !ctx.taxProfile.isTaxProfileConfigured {
            score -= 10
        }

        score -= min(25, sanity.warnings.count * 5)

        let clamped = max(0, min(100, score))
        let band: TaxHealthBand = clamped >= 75 ? .green : (clamped >= 50 ? .yellow : .red)
        let risk = band == .green ? "Low" : (band == .yellow ? "Medium" : "Elevated")

        return TaxHealthSnapshot(score: clamped, band: band, riskLevel: risk, recommendations: recs)
    }
}

// MARK: - Tax Autopilot Engine

public enum TaxAutopilotEngine {
    public static func compute(
        _ ctx: TaxStudioContext,
        intelligence: TaxIntelligenceSnapshot,
        forecast: TaxForecastSnapshot,
        health: TaxHealthSnapshot
    ) -> [TaxAutopilotInsight] {
        var items: [TaxAutopilotInsight] = []
        let calendar = Calendar.current

        if let next = intelligence.quarterly.nextPaymentDate {
            let days = max(1, calendar.dateComponents([.day], from: ctx.now, to: next).day ?? 30)
            let daily = intelligence.quarterly.suggestedSetAside / Decimal(days)
            if daily > 0 {
                items.append(.init(
                    id: "setaside",
                    message: "Set aside \(formatMoney(daily)) today toward your quarterly tax pot.",
                    icon: "banknote.fill",
                    priority: 1
                ))
            }
        }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: ctx.now) ?? ctx.now
        let weekReceipts = ctx.receipts.filter { $0.date >= weekAgo && $0.isDeductible }
        let weekSavings = StudioDeductionMath.totalDeductible(receipts: weekReceipts)
        let rate = ((ctx.taxProfile.estimatedIncomeTaxRatePercent ?? 0)
            + (ctx.taxProfile.estimatedSelfEmployedRatePercent ?? 0)) / 100
        if weekSavings > 0 {
            items.append(.init(
                id: "dedweek",
                message: "You captured about \(formatMoney(weekSavings * rate)) in tax savings from deductions this week.",
                icon: "leaf.fill",
                priority: 2
            ))
        }

        if forecast.projectedEffectiveRate > intelligence.breakdown.effectiveRate + 0.02 {
            items.append(.init(
                id: "trend",
                message: "Your effective tax rate is trending upward based on recent income velocity.",
                icon: "chart.line.uptrend.xyaxis",
                priority: 3
            ))
        }

        if intelligence.quarterly.totalDue > 0 {
            items.append(.init(
                id: "qtrack",
                message: "Quarterly payment trajectory is on track for \(intelligence.quarterly.quarterLabel).",
                icon: "calendar.badge.clock",
                priority: 4
            ))
        }

        if let eta = forecast.vatRegistrationETA {
            let days = calendar.dateComponents([.day], from: ctx.now, to: eta).day ?? 0
            if days > 0, days < 365 {
                items.append(.init(
                    id: "vateta",
                    message: "VAT/GST registration threshold may be reached in about \(days) days at current pace.",
                    icon: "exclamationmark.triangle.fill",
                    priority: 5
                ))
            }
        }

        if forecast.projectedRunwayAfterTaxMonths > 0 {
            items.append(.init(
                id: "runway",
                message: String(format: "Runway after tax is about %.1f months at current burn.", forecast.projectedRunwayAfterTaxMonths),
                icon: "hourglass",
                priority: 6
            ))
        }

        if health.band == .red {
            items.append(.init(
                id: "health",
                message: "Tax health needs attention — open Health Score for actions.",
                icon: "heart.text.square.fill",
                priority: 0
            ))
        }

        return items.sorted { $0.priority < $1.priority }
    }

    private static func formatMoney(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value)
        return NumberFormatter.localizedString(from: n, number: .currency)
    }
}

// MARK: - Tax Coach Engine

public enum TaxCoachEngine {
    public static func compute(
        _ ctx: TaxStudioContext,
        intelligence: TaxIntelligenceSnapshot,
        forecast: TaxForecastSnapshot,
        health: TaxHealthSnapshot
    ) -> [TaxCoachCard] {
        var cards: [TaxCoachCard] = []

        cards.append(.init(
            id: "disclaimer",
            title: "Verify locally",
            body: TaxReferenceCopy.coachFooter,
            category: "Important"
        ))

        if let preset = ctx.countryPreset {
            if !preset.vat.isEmpty {
                cards.append(.init(
                    id: "vatguide",
                    title: "Indirect tax reference",
                    body: String(preset.vat.prefix(280)),
                    category: "VAT/GST"
                ))
            }
        }

        let deductions = StudioDeductionEngine.computeDeductions(
            receipts: ctx.receipts,
            taxProfile: ctx.taxProfile,
            mileageEntries: ctx.mileageEntries,
            mileageRatePerUnit: SettingsStore.shared.mileageRatePerUnit
        )
        for opp in deductions.opportunities.prefix(3) {
            cards.append(.init(
                id: "ded-\(opp.id.uuidString)",
                title: opp.title,
                body: opp.description,
                category: "Deductions"
            ))
        }

        let risky = ctx.receipts.filter {
            $0.category.lowercased().contains("meal") || $0.category.lowercased().contains("travel")
        }
        if !risky.isEmpty {
            cards.append(.init(
                id: "audit",
                title: "Audit-sensitive categories",
                body: "Meals and travel often face scrutiny — keep business purpose notes on \(risky.count) matching expenses.",
                category: "Risk"
            ))
        }

        let month = Calendar.current.component(.month, from: ctx.now)
        if month >= 10 {
            cards.append(.init(
                id: "eoy",
                title: "Year-end preparation",
                body: "Reconcile paid invoices, attach missing receipts, and confirm effective rates before your tax year closes.",
                category: "Calendar"
            ))
        }

        if ctx.taxProfile.paymentSchedule == "quarterly" {
            cards.append(.init(
                id: "quarterly",
                title: "Quarterly payments",
                body: "Set aside \(intelligence.quarterly.quarterLabel) funds before \(forecast.projectedQuarterlyPayment > 0 ? "your next deadline" : "rates are configured").",
                category: "Quarterly"
            ))
        }

        switch ctx.profile.businessType {
        case .soleTrader, .selfEmployed:
            cards.append(.init(
                id: "structure",
                title: "Business structure",
                body: "Sole trader / self-employed structures are common for solo operators — compare liability and admin with a local advisor.",
                category: "Structure"
            ))
        default:
            break
        }

        if health.score < 60 {
            cards.append(.init(
                id: "healthcoach",
                title: "Improve tax health",
                body: "Complete your tax profile, categorize receipts, and set effective rates to raise your score.",
                category: "Health"
            ))
        }

        return cards
    }
}

// MARK: - Tax Timeline Engine

public enum TaxTimelineEngine {
    public static func compute(
        _ ctx: TaxStudioContext,
        intelligence: TaxIntelligenceSnapshot,
        forecast: TaxForecastSnapshot
    ) -> [TaxTimelineEvent] {
        var events: [TaxTimelineEvent] = []
        let calendar = Calendar.current

        if let next = intelligence.quarterly.nextPaymentDate {
            events.append(.init(
                id: "qpay-\(next.timeIntervalSince1970)",
                date: next,
                title: "Quarterly tax payment",
                subtitle: intelligence.quarterly.quarterLabel,
                severity: .warning,
                deepLink: .quarterly
            ))
        }

        for monthOffset in [0, 3, 6, 9] {
            if let d = calendar.date(byAdding: .month, value: monthOffset, to: ctx.now) {
                events.append(.init(
                    id: "qest-\(monthOffset)",
                    date: d,
                    title: "Estimated tax checkpoint",
                    subtitle: "Review set-aside vs. \(intelligence.quarterly.quarterLabel) liability",
                    severity: .info,
                    deepLink: .calculator
                ))
            }
        }

        if let eta = forecast.vatRegistrationETA {
            events.append(.init(
                id: "vat-eta",
                date: eta,
                title: "VAT/GST threshold projection",
                subtitle: "Review registration obligations",
                severity: .critical,
                deepLink: .settings
            ))
        }

        var yearEnd = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: ctx.now),
            month: ctx.profile.taxYearStartMonth == 1 ? 12 : ctx.profile.taxYearStartMonth,
            day: 1
        )) ?? ctx.now
        if yearEnd < ctx.now {
            yearEnd = calendar.date(byAdding: .year, value: 1, to: yearEnd) ?? yearEnd
        }
        events.append(.init(
            id: "annual",
            date: yearEnd,
            title: "Tax year milestone",
            subtitle: "Annual filing preparation window",
            severity: .info,
            deepLink: .coach
        ))

        for warning in intelligence.thresholdWarnings.enumerated() {
            events.append(.init(
                id: "thr-\(warning.offset)",
                date: ctx.now,
                title: "Threshold alert",
                subtitle: warning.element,
                severity: .warning,
                deepLink: .overview
            ))
        }

        return events.sorted { $0.date < $1.date }
    }
}

// MARK: - Tax Sanity Check Engine

public enum TaxSanityCheckEngine {
    public static func compute(_ ctx: TaxStudioContext) -> TaxSanitySnapshot {
        var warnings: [TaxSanityWarning] = []

        let quarterly = QuarterlyTaxEngine.currentQuarterEstimate(
            invoices: ctx.invoices,
            receipts: ctx.receipts,
            taxProfile: ctx.taxProfile,
            taxYearStartMonth: ctx.profile.taxYearStartMonth,
            now: ctx.now
        )
        let compliance = ComplianceAssistantEngine.analyze(
            taxProfile: ctx.taxProfile,
            invoices: ctx.invoices,
            receipts: ctx.receipts,
            quarterly: quarterly,
            countryCode: ctx.taxProfile.selectedTaxCountry ?? ctx.profile.countryCode
        )
        for item in compliance.warnings {
            warnings.append(.init(
                id: "cmp-\(item.id)",
                title: item.question,
                detail: item.answer,
                suggestion: "Review in Compliance",
                deepLink: .overview
            ))
        }

        if ctx.receipts.isEmpty, !ctx.invoices.filter({ $0.status == .paid }).isEmpty {
            warnings.append(.init(
                id: "no-exp",
                title: "No expenses logged",
                detail: "Paid income exists without offsetting business expenses.",
                suggestion: "Scan or add receipts in Studio.",
                deepLink: .receipts
            ))
        }

        if ctx.taxProfile.estimatedIncomeTaxRatePercent == nil {
            warnings.append(.init(
                id: "rate-inc",
                title: "Missing income tax %",
                detail: "Effective income tax override is not set.",
                suggestion: "Open Tax Studio Settings.",
                deepLink: .settings
            ))
        }

        let rolling = TaxIntelligenceEngine.rollingTwelveMonthGross(invoices: ctx.invoices, now: ctx.now)
        if rolling > 75_000, !ctx.taxProfile.vatRegistered {
            warnings.append(.init(
                id: "vat-near",
                title: "VAT/GST proximity",
                detail: "Turnover may be nearing common registration thresholds.",
                suggestion: "Review indirect tax registration.",
                deepLink: .settings
            ))
        }

        return TaxSanitySnapshot(warnings: warnings)
    }
}

// MARK: - Orchestrator

public enum TaxStudioOrchestrator {
    public static func buildSnapshot(_ ctx: TaxStudioContext) -> TaxStudioSnapshot {
        let intelligence = TaxIntelligenceEngine.compute(ctx)
        let sanity = TaxSanityCheckEngine.compute(ctx)
        let forecast = TaxForecastingEngine.compute(ctx, intelligence: intelligence)
        let health = TaxHealthScoreEngine.compute(ctx, intelligence: intelligence, sanity: sanity)
        let autopilot = TaxAutopilotEngine.compute(ctx, intelligence: intelligence, forecast: forecast, health: health)
        let coach = TaxCoachEngine.compute(ctx, intelligence: intelligence, forecast: forecast, health: health)
        let timeline = TaxTimelineEngine.compute(ctx, intelligence: intelligence, forecast: forecast)

        return TaxStudioSnapshot(
            intelligence: intelligence,
            forecast: forecast,
            health: health,
            autopilot: autopilot,
            coach: coach,
            timeline: timeline,
            sanity: sanity
        )
    }
}
