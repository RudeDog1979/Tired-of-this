//
//  TaxEnvelopeEngine.swift
//  BuxMuse
//
//  Catalog-backed set-aside, jar targets, and quarterly coach — no hardcoded tax advice.
//

import Foundation

public enum TaxEnvelopeEngine {

    // MARK: - Set-aside rate

    public static func resolveSaveRate(
        context: TaxEnvelopeSourceContext,
        period: TaxComputationPeriod = .fiscalYearToDate(reference: Date())
    ) -> (rate: Decimal, source: TaxEnvelopeRateSource, taxYear: String?, rulesAsOf: String?) {
        if let override = context.envelope.recommendedSaveRateOverride, override > 0 {
            return (override, .userOverride, catalogTaxYear(context: context), catalogUpdatedAt(context: context))
        }

        let countryCode = context.countryCode
        let regionCode = context.taxProfile.regionCode ?? context.profile.regionCode
        if let entry = TaxComputeCatalogStore.shared.entry(for: countryCode) {
            let block = entry.mergedBlock(forRegion: regionCode)
            if let advances = block.advancePayments, !advances.isEmpty {
                let sum = advances.reduce(Decimal(0)) { $0 + $1.rateOnGross }
                if sum > 0 {
                    return (sum, .catalogAdvancePayments, entry.meta.taxYear, TaxComputeCatalogStore.shared.payload?.updatedAt)
                }
            }
        }

        let request = TaxEnvelopeContextBridge.computationRequest(from: context, period: period)
        let result = WorldTaxEngine.compute(request)

        if let marginal = result.lines.first(where: { $0.kind == .marginalRate })?.rate, marginal > 0 {
            return (marginal, .catalogMarginalRate, result.taxYear, result.catalogUpdatedAt)
        }

        let effective = Decimal(result.legacyBreakdown.effectiveRate)
        if effective > 0 {
            return (effective, .catalogEffectiveRate, result.taxYear, result.catalogUpdatedAt)
        }

        if result.source == .legacyManualRates,
           let manual = manualFallbackRate(taxProfile: context.taxProfile) {
            return (manual, .legacyManualRates, result.taxYear, result.catalogUpdatedAt)
        }

        return (0, .catalogEffectiveRate, result.taxYear, result.catalogUpdatedAt)
    }

    public static func setAsideForIncome(
        grossIncome: Decimal,
        context: TaxEnvelopeSourceContext
    ) -> TaxEnvelopeSetAsideResult {
        let period = WorldTaxEngine.defaultHubPeriod(
            countryCode: context.countryCode,
            reference: context.now
        )
        let (rate, source, taxYear, rulesAsOf) = resolveSaveRate(context: context, period: period)
        let amount = max(0, grossIncome * rate)
        return TaxEnvelopeSetAsideResult(
            amount: amount,
            rateFraction: rate,
            rateSource: source,
            catalogTaxYear: taxYear,
            rulesAsOf: rulesAsOf
        )
    }

    public static func onboardingRecommendation(
        context: TaxEnvelopeSourceContext
    ) -> TaxEnvelopeOnboardingRecommendation {
        let (rate, source, _, _) = resolveSaveRate(context: context)
        let schedule = TaxCatalogProfileHydrator.catalogPaymentSchedule(
            countryCode: context.countryCode,
            regionCode: context.taxProfile.regionCode
        ) ?? context.taxProfile.paymentSchedule
        let percent = Int(truncating: (rate * 100) as NSDecimalNumber)
        return TaxEnvelopeOnboardingRecommendation(
            saveRatePercent: max(0, percent),
            saveRateSource: source,
            countryCode: context.countryCode,
            paymentSchedule: schedule,
            coachLine: coachLine(for: source, ratePercent: percent, locale: context.locale)
        )
    }

    // MARK: - Quarterly

    public static func quarterlyEstimate(context: TaxEnvelopeSourceContext) -> QuarterlyTaxEstimate {
        let countryCode = context.countryCode
        let period = WorldTaxEngine.defaultQuarterPeriod(countryCode: countryCode, reference: context.now)
        let request = TaxEnvelopeContextBridge.computationRequest(from: context, period: period)
        let (start, end) = WorldTaxEngine.periodBounds(for: request)
        let label = WorldTaxEngine.quarterLabel(
            countryCode: countryCode,
            reference: context.now
        )
        let breakdown = WorldTaxEngine.compute(request).legacyBreakdown
        let schedule = context.taxProfile.paymentSchedule
        let nextPayment = TaxEnvelopePaymentSchedule.nextPaymentDate(
            countryCode: countryCode,
            regionCode: context.taxProfile.regionCode,
            schedule: schedule,
            reference: context.now
        )
        let setAside = breakdown.totalEstimatedTax + breakdown.indirectTaxNet
        return QuarterlyTaxEstimate(
            quarterLabel: label,
            periodStart: start ?? context.now,
            periodEnd: end ?? context.now,
            incomeTax: breakdown.incomeTax,
            selfEmployedTax: breakdown.selfEmployedTax,
            indirectTaxCollected: breakdown.indirectTaxNet,
            totalDue: breakdown.totalEstimatedTax + breakdown.indirectTaxNet,
            nextPaymentDate: nextPayment,
            suggestedSetAside: setAside,
            breakdown: breakdown
        )
    }

    // MARK: - Jar

    public static func jarSavedTotal(envelope: TaxEnvelopeState) -> Decimal {
        envelope.deposits.reduce(0) { $0 + $1.amount }
    }

    public static func fiscalYearSetAsideTarget(
        context: TaxEnvelopeSourceContext
    ) -> Decimal {
        let period = WorldTaxEngine.defaultHubPeriod(
            countryCode: context.countryCode,
            reference: context.now
        )
        let request = TaxEnvelopeContextBridge.computationRequest(from: context, period: period)
        let breakdown = WorldTaxEngine.compute(request).legacyBreakdown
        return breakdown.totalEstimatedTax + breakdown.indirectTaxNet
    }

    // MARK: - Tax tile (Simple Studio)

    public static func taxTileMightOwe(
        made: Decimal,
        spent: Decimal,
        context: TaxEnvelopeSourceContext?
    ) -> Decimal {
        guard let context, context.envelope.isEnabled else {
            return max(0, (made - spent) * Decimal(0.15))
        }
        let keep = made - spent
        guard keep > 0 else { return 0 }
        let (rate, _, _, _) = resolveSaveRate(context: context)
        return max(0, keep * rate)
    }

    public static func taxTileCoachLine(
        context: TaxEnvelopeSourceContext?,
        persona: StudioPersona,
        locale: Locale
    ) -> String {
        guard let context, context.envelope.isEnabled else {
            return SimpleStudioEngine.legacyCoachLine(for: persona, locale: locale)
        }
        let (rate, source, _, _) = resolveSaveRate(context: context)
        let percent = Int(truncating: (rate * 100) as NSDecimalNumber)
        switch source {
        case .catalogAdvancePayments, .catalogMarginalRate, .catalogEffectiveRate:
            return BuxLocalizedString.format(
                "Set-aside uses BuxMuse Intelligence for your country (%lld%% guide).",
                locale: locale,
                percent
            )
        case .userOverride:
            return BuxLocalizedString.format(
                "You chose to set aside %lld%% from each payment.",
                locale: locale,
                percent
            )
        case .legacyManualRates:
            return BuxLocalizedString.format(
                "Set-aside follows your tax profile rates (%lld%% guide).",
                locale: locale,
                percent
            )
        }
    }

    // MARK: - Private

    private static func manualFallbackRate(taxProfile: StudioTaxProfile) -> Decimal? {
        let income = (taxProfile.estimatedIncomeTaxRatePercent ?? 0) / 100
        let se = (taxProfile.estimatedSelfEmployedRatePercent ?? 0) / 100
        let sum = income + se
        return sum > 0 ? sum : nil
    }

    private static func catalogTaxYear(context: TaxEnvelopeSourceContext) -> String? {
        TaxComputeCatalogStore.shared.entry(for: context.countryCode)?.meta.taxYear
    }

    private static func catalogUpdatedAt(context: TaxEnvelopeSourceContext) -> String? {
        TaxComputeCatalogStore.shared.payload?.updatedAt
    }

    private static func coachLine(
        for source: TaxEnvelopeRateSource,
        ratePercent: Int,
        locale: Locale
    ) -> String {
        switch source {
        case .catalogAdvancePayments, .catalogMarginalRate, .catalogEffectiveRate:
            return BuxLocalizedString.format(
                "BuxMuse Intelligence suggests about %lld%% for your country — a good starting point.",
                locale: locale,
                ratePercent
            )
        case .userOverride:
            return BuxCatalogLabel.string(
                "You can adjust this anytime in tax savings settings.",
                locale: locale
            )
        case .legacyManualRates:
            return BuxLocalizedString.format(
                "Using rates from your tax profile — about %lld%%.",
                locale: locale,
                ratePercent
            )
        }
    }
}
