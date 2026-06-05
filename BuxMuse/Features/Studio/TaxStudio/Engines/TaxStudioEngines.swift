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
        let locale = ctx.locale
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
            rules: ctx.taxProfile.incomeTaxRules,
            locale: locale
        )
        let warnings = thresholdWarnings(ctx: ctx, breakdown: breakdown, locale: locale)

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

    private static func bracketProximity(
        taxable: Decimal,
        rules: [TaxBracketRule],
        locale: Locale
    ) -> (String, Int) {
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
                return (
                    TaxStudioL10n.format("Approaching %@ taxable band", locale: locale, label),
                    min(99, pct)
                )
            }
            return (TaxStudioL10n.line("Highest heuristic band", locale: locale), 100)
        }
        let sorted = rules.sorted { $0.lowerBound < $1.lowerBound }
        for rule in sorted where taxable < rule.lowerBound {
            let pct = rule.lowerBound > 0
                ? Int(truncating: ((taxable / rule.lowerBound) * 100) as NSDecimalNumber)
                : 0
            return (
                TaxStudioL10n.format(
                    "Approaching %@ threshold",
                    locale: locale,
                    "\(rule.lowerBound)"
                ),
                min(99, pct)
            )
        }
        return (TaxStudioL10n.line("Top bracket in profile", locale: locale), 100)
    }

    private static func thresholdWarnings(
        ctx: TaxStudioContext,
        breakdown: IncomeTaxBreakdown,
        locale: Locale
    ) -> [String] {
        var items: [String] = []
        let rollingGross = rollingTwelveMonthGross(invoices: ctx.invoices, now: ctx.now)
        if !ctx.taxProfile.vatRegistered, rollingGross >= 85_000 {
            items.append(
                TaxStudioL10n.line(
                    "Rolling 12-month turnover may approach VAT/GST registration thresholds — review local rules.",
                    locale: locale
                )
            )
        }
        if breakdown.taxableIncome > 0,
           ctx.taxProfile.estimatedIncomeTaxRatePercent == nil,
           ctx.taxProfile.estimatedSelfEmployedRatePercent == nil {
            items.append(
                TaxStudioL10n.line(
                    "Set effective tax rates in Tax studio settings for accurate estimates.",
                    locale: locale
                )
            )
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
        let locale = ctx.locale
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

        let seasonality = TaxForecastingEngine.seasonalityFactor(for: ctx.now, calendar: calendar)
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

        let bracketLabel = effective > intelligence.breakdown.effectiveRate
            ? TaxStudioL10n.line("Q3–Q4", locale: locale)
            : nil

        return TaxForecastSnapshot(
            projectedTaxableIncome: projectedTaxable,
            projectedTaxOwed: projectedTax,
            projectedQuarterlyPayment: projectedQuarterly,
            projectedEffectiveRate: effective,
            projectedRunwayAfterTaxMonths: min(24, max(0, runway)),
            vatRegistrationETA: vatETA,
            bracketChangeMonthLabel: bracketLabel,
            monthlyIncomeVelocity: incomeVelocity,
            monthlyExpenseVelocity: expenseVelocity
        )
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
        let locale = ctx.locale
        var score = 100
        var recs: [TaxHealthRecommendation] = []

        let categorized = ctx.receipts.filter { !$0.category.trimmingCharacters(in: .whitespaces).isEmpty }
        let catRatio = ctx.receipts.isEmpty ? 1.0 : Double(categorized.count) / Double(ctx.receipts.count)
        if catRatio < 0.7 {
            score -= 15
            recs.append(.init(
                id: "cat",
                title: TaxStudioL10n.line("Categorize expenses", locale: locale),
                detail: TaxStudioL10n.line("Tag receipts with business categories to maximize defensible deductions.", locale: locale),
                band: .yellow
            ))
        }

        let deductions = StudioDeductionEngine.computeDeductions(
            receipts: ctx.receipts,
            taxProfile: ctx.taxProfile,
            mileageEntries: ctx.mileageEntries,
            mileageRatePerUnit: SettingsStore.shared.mileageRatePerUnit,
            locale: ctx.locale
        )
        if !deductions.opportunities.isEmpty {
            score -= 10
            recs.append(.init(
                id: "ded",
                title: TaxStudioL10n.line("Deduction opportunities", locale: locale),
                detail: TaxStudioL10n.line("Review suggested deductions in Studio receipts.", locale: locale),
                band: .yellow
            ))
        }

        let missingImages = ctx.receipts.filter { ($0.localImagePath ?? "").isEmpty }.count
        if !ctx.receipts.isEmpty, missingImages > ctx.receipts.count / 3 {
            score -= 12
            recs.append(.init(
                id: "rcpt",
                title: TaxStudioL10n.line("Attach receipts", locale: locale),
                detail: TaxStudioL10n.line("Missing receipt images weaken audit readiness.", locale: locale),
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
                title: TaxStudioL10n.line("VAT/GST threshold", locale: locale),
                detail: TaxStudioL10n.line("Turnover is approaching common registration thresholds.", locale: locale),
                band: .red
            ))
        }

        if ctx.taxProfile.estimatedIncomeTaxRatePercent == nil && ctx.taxProfile.estimatedSelfEmployedRatePercent == nil {
            score -= 20
            recs.append(.init(
                id: "rates",
                title: TaxStudioL10n.line("Set effective rates", locale: locale),
                detail: TaxStudioL10n.line("Add income and self-employed % overrides in Tax studio settings.", locale: locale),
                band: .red
            ))
        }

        if !ctx.taxProfile.isTaxProfileConfigured {
            score -= 10
        }

        score -= min(25, sanity.warnings.count * 5)

        let clamped = max(0, min(100, score))
        let band: TaxHealthBand = clamped >= 75 ? .green : (clamped >= 50 ? .yellow : .red)
        let riskKey = band == .green ? "Low" : (band == .yellow ? "Medium" : "Elevated")

        let taggingProgress = catRatio
        let taggingLabel = TaxStudioL10n.format(
            "%lld%% tagged",
            locale: locale,
            Int64(Int(catRatio * 100))
        )

        let scheduleFactor = healthScheduleFactor(
            taxProfile: ctx.taxProfile,
            intelligence: intelligence,
            locale: locale
        )
        let ratesFactor = healthRatesFactor(taxProfile: ctx.taxProfile, locale: locale)

        let factors: [TaxHealthFactor] = [
            .init(
                id: "tagging",
                title: TaxStudioL10n.line("Expense tagging", locale: locale),
                valueLabel: taggingLabel,
                progress: taggingProgress
            ),
            scheduleFactor,
            ratesFactor
        ]

        return TaxHealthSnapshot(
            score: clamped,
            band: band,
            riskLevel: TaxStudioL10n.line(riskKey, locale: locale),
            factors: factors,
            recommendations: recs
        )
    }

    private static func healthScheduleFactor(
        taxProfile: StudioTaxProfile,
        intelligence: TaxIntelligenceSnapshot,
        locale: Locale
    ) -> TaxHealthFactor {
        let schedule = taxProfile.paymentSchedule.lowercased()
        if schedule == "quarterly" {
            if intelligence.quarterly.nextPaymentDate != nil {
                return .init(
                    id: "schedule",
                    title: TaxStudioL10n.line("Payment schedule", locale: locale),
                    valueLabel: TaxStudioL10n.line("Quarterly on track", locale: locale),
                    progress: 1
                )
            }
            return .init(
                id: "schedule",
                title: TaxStudioL10n.line("Payment schedule", locale: locale),
                valueLabel: TaxStudioL10n.line("Quarterly needs dates", locale: locale),
                progress: 0.55
            )
        }
        let labelKey = schedule == "monthly" ? "Monthly" : (schedule == "annually" ? "Annually" : "Custom")
        return .init(
            id: "schedule",
            title: TaxStudioL10n.line("Payment schedule", locale: locale),
            valueLabel: TaxStudioL10n.line(labelKey, locale: locale),
            progress: 0.85
        )
    }

    private static func healthRatesFactor(taxProfile: StudioTaxProfile, locale: Locale) -> TaxHealthFactor {
        let hasIncome = taxProfile.estimatedIncomeTaxRatePercent != nil
        let hasSE = taxProfile.estimatedSelfEmployedRatePercent != nil
        if hasIncome || hasSE {
            let total = (taxProfile.estimatedIncomeTaxRatePercent ?? 0)
                + (taxProfile.estimatedSelfEmployedRatePercent ?? 0)
            return .init(
                id: "rates",
                title: TaxStudioL10n.line("Effective rates", locale: locale),
                valueLabel: TaxStudioL10n.format(
                    "%lld%% combined",
                    locale: locale,
                    Int64(NSDecimalNumber(decimal: total).intValue)
                ),
                progress: 1
            )
        }
        return .init(
            id: "rates",
            title: TaxStudioL10n.line("Effective rates", locale: locale),
            valueLabel: TaxStudioL10n.line("Not configured", locale: locale),
            progress: 0.35
        )
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
        let locale = ctx.locale
        var items: [TaxAutopilotInsight] = []
        let calendar = Calendar.current

        if let next = intelligence.quarterly.nextPaymentDate {
            let days = max(1, calendar.dateComponents([.day], from: ctx.now, to: next).day ?? 30)
            let daily = intelligence.quarterly.suggestedSetAside / Decimal(days)
            if daily > 0 {
                items.append(.init(
                    id: "setaside",
                    message: TaxStudioL10n.format(
                        "Set aside %@ today toward your quarterly tax pot.",
                        locale: locale,
                        formatMoney(daily, locale: locale)
                    ),
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
                message: TaxStudioL10n.format(
                    "You captured about %@ in tax savings from deductions this week.",
                    locale: locale,
                    formatMoney(weekSavings * rate, locale: locale)
                ),
                icon: "leaf.fill",
                priority: 2
            ))
        }

        if forecast.projectedEffectiveRate > intelligence.breakdown.effectiveRate + 0.02 {
            items.append(.init(
                id: "trend",
                message: TaxStudioL10n.line(
                    "Your effective tax rate is trending upward based on recent income velocity.",
                    locale: locale
                ),
                icon: "chart.line.uptrend.xyaxis",
                priority: 3
            ))
        }

        if intelligence.quarterly.totalDue > 0 {
            items.append(.init(
                id: "qtrack",
                message: TaxStudioL10n.format(
                    "Quarterly payment trajectory is on track for %@.",
                    locale: locale,
                    intelligence.quarterly.quarterLabel
                ),
                icon: "calendar.badge.clock",
                priority: 4
            ))
        }

        if let eta = forecast.vatRegistrationETA {
            let days = calendar.dateComponents([.day], from: ctx.now, to: eta).day ?? 0
            if days > 0, days < 365 {
                items.append(.init(
                    id: "vateta",
                    message: TaxStudioL10n.format(
                        "VAT/GST registration threshold may be reached in about %lld days at current pace.",
                        locale: locale,
                        Int64(days)
                    ),
                    icon: "exclamationmark.triangle.fill",
                    priority: 5
                ))
            }
        }

        if forecast.projectedRunwayAfterTaxMonths > 0 {
            items.append(.init(
                id: "runway",
                message: TaxStudioL10n.format(
                    "Runway after tax is about %.1f months at current burn.",
                    locale: locale,
                    forecast.projectedRunwayAfterTaxMonths
                ),
                icon: "hourglass",
                priority: 6
            ))
        }

        if health.band == .red {
            items.append(.init(
                id: "health",
                message: TaxStudioL10n.line(
                    "Tax health needs attention — open Health Score for actions.",
                    locale: locale
                ),
                icon: "heart.text.square.fill",
                priority: 0
            ))
        }

        return items.sorted { $0.priority < $1.priority }
    }

    private static func formatMoney(_ value: Decimal, locale: Locale) -> String {
        let n = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: n) ?? NumberFormatter.localizedString(from: n, number: .currency)
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
        let locale = ctx.locale
        var cards: [TaxCoachCard] = []

        cards.append(.init(
            id: "disclaimer",
            title: TaxStudioL10n.line("Verify locally", locale: locale),
            body: TaxStudioL10n.line(TaxReferenceCopy.coachFooter, locale: locale),
            category: TaxStudioL10n.line("Important", locale: locale)
        ))

        if let preset = ctx.countryPreset {
            if !preset.vat.isEmpty {
                cards.append(.init(
                    id: "vatguide",
                    title: TaxStudioL10n.line("Indirect tax reference", locale: locale),
                    body: TaxCountryPresetL10n.vatSummary(countryCode: preset.isoCode, locale: locale),
                    category: TaxStudioL10n.line("VAT/GST", locale: locale)
                ))
            }
        }

        let deductions = StudioDeductionEngine.computeDeductions(
            receipts: ctx.receipts,
            taxProfile: ctx.taxProfile,
            mileageEntries: ctx.mileageEntries,
            mileageRatePerUnit: SettingsStore.shared.mileageRatePerUnit,
            locale: locale
        )
        for opp in deductions.opportunities.prefix(3) {
            cards.append(.init(
                id: "ded-\(opp.id.uuidString)",
                title: opp.title,
                body: opp.description,
                category: TaxStudioL10n.line("Deductions", locale: locale)
            ))
        }

        let risky = ctx.receipts.filter {
            $0.category.lowercased().contains("meal") || $0.category.lowercased().contains("travel")
        }
        if !risky.isEmpty {
            cards.append(.init(
                id: "audit",
                title: TaxStudioL10n.line("Audit-sensitive categories", locale: locale),
                body: TaxStudioL10n.format(
                    "Meals and travel often face scrutiny — keep business purpose notes on %lld matching expenses.",
                    locale: locale,
                    Int64(risky.count)
                ),
                category: TaxStudioL10n.line("Risk", locale: locale)
            ))
        }

        let month = Calendar.current.component(.month, from: ctx.now)
        if month >= 10 {
            cards.append(.init(
                id: "eoy",
                title: TaxStudioL10n.line("Year-end preparation", locale: locale),
                body: TaxStudioL10n.line(
                    "Reconcile paid invoices, attach missing receipts, and confirm effective rates before your tax year closes.",
                    locale: locale
                ),
                category: TaxStudioL10n.line("Calendar", locale: locale)
            ))
        }

        if ctx.taxProfile.paymentSchedule == "quarterly" {
            let bodyKey = forecast.projectedQuarterlyPayment > 0
                ? "Set aside %@ funds before your next deadline."
                : "Set aside %@ funds before rates are configured."
            cards.append(.init(
                id: "quarterly",
                title: TaxStudioL10n.line("Quarterly payments", locale: locale),
                body: TaxStudioL10n.format(
                    bodyKey,
                    locale: locale,
                    intelligence.quarterly.quarterLabel
                ),
                category: TaxStudioL10n.line("Quarterly", locale: locale)
            ))
        }

        switch ctx.profile.businessType {
        case .soleTrader, .selfEmployed:
            cards.append(.init(
                id: "structure",
                title: TaxStudioL10n.line("Business structure", locale: locale),
                body: TaxStudioL10n.line(
                    "Sole trader / self-employed structures are common for solo operators — compare liability and admin with a local advisor.",
                    locale: locale
                ),
                category: TaxStudioL10n.line("Structure", locale: locale)
            ))
        default:
            break
        }

        if health.score < 60 {
            cards.append(.init(
                id: "healthcoach",
                title: TaxStudioL10n.line("Improve tax health", locale: locale),
                body: TaxStudioL10n.line(
                    "Complete your tax profile, categorize receipts, and set effective rates to raise your score.",
                    locale: locale
                ),
                category: TaxStudioL10n.line("Health", locale: locale)
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
        let locale = ctx.locale
        var events: [TaxTimelineEvent] = []
        let calendar = Calendar.current

        if let next = intelligence.quarterly.nextPaymentDate {
            events.append(.init(
                id: "qpay-\(next.timeIntervalSince1970)",
                date: next,
                title: TaxStudioL10n.line("Quarterly tax payment", locale: locale),
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
                    title: TaxStudioL10n.line("Estimated tax checkpoint", locale: locale),
                    subtitle: TaxStudioL10n.format(
                        "Review set-aside vs. %@ liability",
                        locale: locale,
                        intelligence.quarterly.quarterLabel
                    ),
                    severity: .info,
                    deepLink: .calculator
                ))
            }
        }

        if let eta = forecast.vatRegistrationETA {
            events.append(.init(
                id: "vat-eta",
                date: eta,
                title: TaxStudioL10n.line("VAT/GST threshold projection", locale: locale),
                subtitle: TaxStudioL10n.line("Review registration obligations", locale: locale),
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
            title: TaxStudioL10n.line("Tax year milestone", locale: locale),
            subtitle: TaxStudioL10n.line("Annual filing preparation window", locale: locale),
            severity: .info,
            deepLink: .coach
        ))

        for warning in intelligence.thresholdWarnings.enumerated() {
            events.append(.init(
                id: "thr-\(warning.offset)",
                date: ctx.now,
                title: TaxStudioL10n.line("Threshold alert", locale: locale),
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
        let locale = ctx.locale
        let compliance = ComplianceAssistantEngine.analyze(
            taxProfile: ctx.taxProfile,
            invoices: ctx.invoices,
            receipts: ctx.receipts,
            quarterly: quarterly,
            countryCode: ctx.taxProfile.selectedTaxCountry ?? ctx.profile.countryCode,
            locale: locale
        )
        for item in compliance.warnings {
            warnings.append(.init(
                id: "cmp-\(item.id)",
                title: item.question,
                detail: item.answer,
                suggestion: TaxStudioL10n.line("Review in Compliance", locale: locale),
                deepLink: .overview
            ))
        }

        if ctx.receipts.isEmpty, !ctx.invoices.filter({ $0.status == .paid }).isEmpty {
            warnings.append(.init(
                id: "no-exp",
                title: TaxStudioL10n.line("No expenses logged", locale: locale),
                detail: TaxStudioL10n.line("Paid income exists without offsetting business expenses.", locale: locale),
                suggestion: TaxStudioL10n.line("Scan or add receipts in Studio.", locale: locale),
                deepLink: .receipts
            ))
        }

        if ctx.taxProfile.estimatedIncomeTaxRatePercent == nil {
            warnings.append(.init(
                id: "rate-inc",
                title: TaxStudioL10n.line("Missing income tax %", locale: locale),
                detail: TaxStudioL10n.line("Effective income tax override is not set.", locale: locale),
                suggestion: TaxStudioL10n.line("Open Tax studio settings.", locale: locale),
                deepLink: .settings
            ))
        }

        let rolling = TaxIntelligenceEngine.rollingTwelveMonthGross(invoices: ctx.invoices, now: ctx.now)
        if rolling > 75_000, !ctx.taxProfile.vatRegistered {
            warnings.append(.init(
                id: "vat-near",
                title: TaxStudioL10n.line("VAT/GST proximity", locale: locale),
                detail: TaxStudioL10n.line("Turnover may be nearing common registration thresholds.", locale: locale),
                suggestion: TaxStudioL10n.line("Review indirect tax registration.", locale: locale),
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

// MARK: - Chart data (Phase C)

public enum TaxStudioChartEngine {
    public static func taxPressureSparkline(
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        effectiveRate: Double,
        months: Int = 6,
        now: Date = Date()
    ) -> [Double] {
        guard effectiveRate > 0 else { return Array(repeating: 0, count: months) }
        let calendar = Calendar.current
        let rate = Decimal(effectiveRate)
        return (0..<months).reversed().map { offset in
            guard
                let monthDate = calendar.date(byAdding: .month, value: -offset, to: now),
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
            else { return 0 }

            let gross = invoices
                .filter { $0.issueDate >= monthStart && $0.issueDate < monthEnd }
                .reduce(Decimal(0)) { $0 + $1.total }
            let deduct = receipts
                .filter { $0.date >= monthStart && $0.date < monthEnd && $0.isDeductible }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let taxable = max(0, gross - deduct)
            let tax = taxable * rate
            return Double(truncating: NSDecimalNumber(decimal: tax))
        }
    }

    public static func forecastMonthlyBars(
        projectedAnnualTax: Decimal,
        locale: Locale,
        now: Date = Date(),
        months: Int = 12
    ) -> [TaxStudioForecastBar] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        let baseMonthly = projectedAnnualTax / Decimal(max(months, 1))
        return (0..<months).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset, to: now) else { return nil }
            let factor = TaxForecastingEngine.seasonalityFactor(for: date, calendar: calendar)
            let value = baseMonthly * factor
            return TaxStudioForecastBar(
                id: "\(offset)",
                monthLabel: formatter.string(from: date),
                value: Double(truncating: NSDecimalNumber(decimal: value))
            )
        }
    }
}

extension TaxForecastingEngine {
    public static func seasonalityFactor(for date: Date, calendar: Calendar) -> Decimal {
        let month = calendar.component(.month, from: date)
        switch month {
        case 11, 12: return Decimal(1.08)
        case 1, 2: return Decimal(0.92)
        default: return Decimal(1.0)
        }
    }
}
