//
//  TaxCatalogProfileHydrator.swift
//  BuxMuse
//
//  Populates structured profile rules from buxmuse_tax_compute.json on preset apply.
//

import Foundation

public enum TaxCatalogProfileHydrator {

    /// Fills `incomeTaxRules`, `vatRules`, and `deductionCategories` from the compute catalog.
    /// Does not overwrite user prose fields, manual effective-rate overrides, or payment schedule.
    public static func applyCatalogRules(
        to profile: inout StudioTaxProfile,
        countryCode: String,
        regionCode: String? = nil
    ) {
        guard let entry = TaxComputeCatalogStore.shared.entry(for: countryCode) else { return }

        let block = entry.block(forRegion: regionCode ?? profile.regionCode)
        let incomePath = profile.taxIncomeType
        let incomeRules: TaxComputeIncomeRules? = {
            switch incomePath {
            case .selfEmployed: return block.selfEmployed
            case .employed: return block.employed ?? block.selfEmployed
            case .oneOff: return block.gig ?? block.selfEmployed
            }
        }()

        if let incomeRules {
            profile.incomeTaxRules = incomeRules.brackets.map {
                TaxBracketRule(lowerBound: $0.from, upperBound: $0.to, rate: $0.rate)
            }
        }

        if let vat = block.vat, vat.standardRate > 0 {
            profile.vatRules = [VatRule(rate: vat.standardRate)]
        }

        if let deductions = block.deductions {
            profile.deductionCategories = deductions.map { rule in
                DeductionCategoryRule(
                    categoryId: rule.categoryId,
                    name: rule.categoryId.capitalized,
                    deductibilityType: deductibilityType(for: rule.deductibility),
                    notes: ""
                )
            }
        }

        let normalized = TaxManager.normalizeCountryCode(countryCode)
        profile.countryCode = normalized
        if profile.regionCode == nil, let regionCode {
            profile.regionCode = regionCode
        }
    }

    /// Jurisdiction default from catalog — use when applying a new country preset, not on every save.
    public static func catalogPaymentSchedule(
        countryCode: String,
        regionCode: String? = nil
    ) -> String? {
        guard let entry = TaxComputeCatalogStore.shared.entry(for: countryCode) else { return nil }
        let block = entry.block(forRegion: regionCode)
        guard let schedule = block.paymentSchedule, !schedule.isEmpty else { return nil }
        return schedule
    }

    private static func deductibilityType(for value: Decimal) -> DeductibilityType {
        if value >= 1 { return .full }
        if value >= 0.5 { return .partial }
        return .limited
    }

    // MARK: - Phase F — manual override visibility

    public static func shouldShowManualIncomeRate(for profile: StudioTaxProfile) -> Bool {
        !hasCatalogIncomeBrackets(for: profile)
    }

    public static func shouldShowManualSelfEmployedRate(for profile: StudioTaxProfile) -> Bool {
        !hasCatalogSocialContributions(for: profile)
    }

    public static func shouldShowManualIndirectRate(for profile: StudioTaxProfile) -> Bool {
        !hasCatalogVATRate(for: profile)
    }

    public static func hasCatalogIncomeBrackets(for profile: StudioTaxProfile) -> Bool {
        if !profile.incomeTaxRules.isEmpty { return true }
        guard let block = catalogBlock(for: profile) else { return false }
        let rules = incomeRules(in: block, path: profile.taxIncomeType)
        return !(rules?.brackets.isEmpty ?? true)
    }

    public static func hasCatalogVATRate(for profile: StudioTaxProfile) -> Bool {
        if !profile.vatRules.isEmpty { return true }
        guard let block = catalogBlock(for: profile) else { return false }
        return (block.vat?.standardRate ?? 0) > 0
    }

    public static func hasCatalogSocialContributions(for profile: StudioTaxProfile) -> Bool {
        guard let block = catalogBlock(for: profile) else { return false }
        let rules = incomeRules(in: block, path: profile.taxIncomeType)
        return !(rules?.socialContributions.isEmpty ?? true)
    }

    private static func catalogBlock(for profile: StudioTaxProfile) -> TaxComputeBlock? {
        let code = profile.selectedTaxCountry ?? profile.countryCode
        guard let entry = TaxComputeCatalogStore.shared.entry(for: code) else { return nil }
        return entry.mergedBlock(forRegion: profile.regionCode)
    }

    private static func incomeRules(
        in block: TaxComputeBlock,
        path: TaxIncomeType
    ) -> TaxComputeIncomeRules? {
        switch path {
        case .selfEmployed: return block.selfEmployed
        case .employed: return block.employed ?? block.selfEmployed
        case .oneOff: return block.gig ?? block.selfEmployed
        }
    }
}
