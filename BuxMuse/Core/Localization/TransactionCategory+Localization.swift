//
//  TransactionCategory+Localization.swift
//  BuxMuse
//
//  System expense categories use English keys in the catalog; localize at display.
//

import Foundation

extension TransactionCategory {
    /// English source key in `Localizable.xcstrings` (matches `displayName`).
    var catalogLabelKey: String { displayName }

    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(catalogLabelKey, locale: locale)
    }
}

extension CustomBudgetCategory {
    /// English catalog key or custom user name in storage — localize only when rendering.
    func localizedDisplayName(
        categoryRecords: [ExpenseCategoryRecord] = [],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> String {
        if let raw = systemCategoryRaw, let system = TransactionCategory(rawValue: raw) {
            return BuxCatalogLabel.string(system.catalogLabelKey, locale: locale)
        }
        if let categoryId, let custom = categoryRecords.first(where: { $0.id == categoryId }) {
            return custom.localizedDisplayName(locale: locale)
        }
        if let system = Self.resolvedSystemCategory(storedName: name) {
            return BuxCatalogLabel.string(system.catalogLabelKey, locale: locale)
        }
        return BuxCatalogLabel.string(name, locale: locale)
    }

    /// Repairs envelopes saved with a localized picker label instead of the English catalog key.
    mutating func normalizeStoredCategoryLink() -> Bool {
        if let raw = systemCategoryRaw, let system = TransactionCategory(rawValue: raw) {
            let key = system.catalogLabelKey
            guard name != key else { return false }
            name = key
            return true
        }
        guard let system = Self.resolvedSystemCategory(storedName: name) else { return false }
        systemCategoryRaw = system.rawValue
        name = system.catalogLabelKey
        return true
    }

    static func resolvedSystemCategory(storedName: String) -> TransactionCategory? {
        let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for system in TransactionCategory.allCases where system != .income {
            if trimmed.caseInsensitiveCompare(system.catalogLabelKey) == .orderedSame {
                return system
            }
            for tag in ["en", "es", "es-419", "es-ES"] {
                let localized = BuxCatalogLabel.string(system.catalogLabelKey, locale: Locale(identifier: tag))
                if trimmed.caseInsensitiveCompare(localized) == .orderedSame {
                    return system
                }
            }
        }
        return nil
    }
}

extension ExpenseCategoryRecord {
    /// Localized chip/list label; custom categories keep user-defined names.
    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        if let raw = systemCategoryRaw, let system = TransactionCategory(rawValue: raw) {
            return system.localizedDisplayName(locale: locale)
        }
        if let system = CustomBudgetCategory.resolvedSystemCategory(storedName: name) {
            return system.localizedDisplayName(locale: locale)
        }
        if isCustom {
            return name
        }
        return BuxCatalogLabel.string(name, locale: locale)
    }

    /// English catalog key for persistence — repairs localized names saved by older builds.
    func normalizedStorageName() -> String {
        if let raw = systemCategoryRaw, let system = TransactionCategory(rawValue: raw) {
            return system.catalogLabelKey
        }
        if let system = CustomBudgetCategory.resolvedSystemCategory(storedName: name) {
            return system.catalogLabelKey
        }
        return name
    }
}
