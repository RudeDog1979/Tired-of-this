//
//  ReceiptDeductionCategoryResolver.swift
//  BuxMuse
//
//  Phase I — receipt/expense category picker from Tax Profile catalog rules.
//

import Foundation

public struct ReceiptDeductionCategoryOption: Identifiable, Equatable {
    public var id: String
    public var labelKey: String
    public var storageValue: String
    public var deductibilityPercent: Int
    public var catalogRule: DeductionCategoryRule?

    public init(
        id: String,
        labelKey: String,
        storageValue: String,
        deductibilityPercent: Int,
        catalogRule: DeductionCategoryRule? = nil
    ) {
        self.id = id
        self.labelKey = labelKey
        self.storageValue = storageValue
        self.deductibilityPercent = deductibilityPercent
        self.catalogRule = catalogRule
    }
}

public enum ReceiptDeductionCategoryResolver {

    public static func pickerOptions(catalogRules: [DeductionCategoryRule]) -> [ReceiptDeductionCategoryOption] {
        guard !catalogRules.isEmpty else {
            return BusinessExpenseCategory.allCases.map { category in
                ReceiptDeductionCategoryOption(
                    id: category.rawValue,
                    labelKey: category.rawValue,
                    storageValue: category.rawValue,
                    deductibilityPercent: Int(category.suggestedPartialPercent ?? 100)
                )
            }
        }

        return catalogRules.map { rule in
            ReceiptDeductionCategoryOption(
                id: rule.categoryId,
                labelKey: rule.name,
                storageValue: rule.name,
                deductibilityPercent: deductibilityPercent(for: rule),
                catalogRule: rule
            )
        }
    }

    public static func defaultCategory(catalogRules: [DeductionCategoryRule]) -> String {
        pickerOptions(catalogRules: catalogRules).first?.storageValue ?? BusinessExpenseCategory.software.rawValue
    }

    public static func deductibilityPercent(for rule: DeductionCategoryRule) -> Int {
        switch rule.deductibilityType {
        case .full: return 100
        case .partial: return 50
        case .limited: return 25
        }
    }

    public static func matchingRule(
        for category: String,
        rules: [DeductionCategoryRule]
    ) -> DeductionCategoryRule? {
        let lower = category.lowercased()
        return rules.first(where: {
            lower.contains($0.categoryId.lowercased())
                || lower.contains($0.name.lowercased())
        })
    }

    public static func suggestedDeductiblePercentage(
        for category: String,
        catalogRules: [DeductionCategoryRule]
    ) -> Double? {
        if let rule = matchingRule(for: category, rules: catalogRules) {
            return Double(deductibilityPercent(for: rule))
        }
        if let expenseCategory = BusinessExpenseCategory.allCases.first(where: { $0.rawValue == category }) {
            return expenseCategory.suggestedPartialPercent ?? 100
        }
        return nil
    }

    public static func deductionStrength(
        for category: String,
        catalogRules: [DeductionCategoryRule]
    ) -> DeductionStrength {
        if let rule = matchingRule(for: category, rules: catalogRules) {
            switch rule.deductibilityType {
            case .full: return .strong
            case .partial: return .medium
            case .limited: return .risky
            }
        }
        if let expenseCategory = BusinessExpenseCategory.allCases.first(where: { $0.rawValue == category }) {
            return expenseCategory.defaultStrength
        }
        return StudioDeductionMath.categoryHint(
            for: category,
            countryCode: ""
        ).strength
    }

    public static func hint(
        for category: String,
        catalogRules: [DeductionCategoryRule],
        countryCode: String,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> (strength: DeductionStrength, note: String) {
        if let rule = matchingRule(for: category, rules: catalogRules) {
            let pct = deductibilityPercent(for: rule)
            let strength = deductionStrength(for: category, catalogRules: catalogRules)
            if !rule.notes.isEmpty {
                return (strength, rule.notes)
            }
            let ruleName = BuxCatalogLabel.string(rule.name, locale: locale)
            if pct < 100 {
                let note = BuxLocalizedString.format(
                    "Catalog rule allows %lld%% deductibility for %@ in %@.",
                    locale: locale,
                    Int64(pct),
                    ruleName,
                    countryCode
                )
                return (strength, note)
            }
            return (
                strength,
                BuxCatalogLabel.string("Fully deductible per your tax profile rules.", locale: locale)
            )
        }
        return StudioDeductionMath.categoryHint(for: category, countryCode: countryCode)
    }

    public static func suggestedCategory(
        merchant: String,
        catalogRules: [DeductionCategoryRule]
    ) -> String {
        let lower = merchant.lowercased()
        let options = pickerOptions(catalogRules: catalogRules)

        if lower.contains("adobe") || lower.contains("figma") || lower.contains("microsoft") || lower.contains("notion") {
            return matchOption(containing: ["software", "subscription"], in: options)
                ?? BusinessExpenseCategory.software.rawValue
        }
        if lower.contains("apple") || lower.contains("best buy") || lower.contains("amazon") {
            return matchOption(containing: ["equipment", "hardware", "tools"], in: options)
                ?? BusinessExpenseCategory.equipment.rawValue
        }
        if lower.contains("uber") || lower.contains("lyft") || lower.contains("hotel") || lower.contains("airbnb") {
            return matchOption(containing: ["travel"], in: options)
                ?? BusinessExpenseCategory.travel.rawValue
        }
        if lower.contains("restaurant") || lower.contains("cafe") || lower.contains("starbucks") {
            return matchOption(containing: ["meal"], in: options)
                ?? BusinessExpenseCategory.meals.rawValue
        }

        return defaultCategory(catalogRules: catalogRules)
    }

    private static func matchOption(
        containing needles: [String],
        in options: [ReceiptDeductionCategoryOption]
    ) -> String? {
        options.first { option in
            let haystack = "\(option.id) \(option.labelKey) \(option.storageValue)".lowercased()
            return needles.contains { haystack.contains($0) }
        }?.storageValue
    }
}
