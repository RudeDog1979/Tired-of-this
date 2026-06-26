//
//  MerchantCategoryAvatarFallback.swift
//  BuxMuse
//
//  SF Symbol + tint when a merchant favicon is loading or unavailable.
//

import Foundation

public struct MerchantCategoryAvatarStyle: Sendable, Equatable {
    public let symbol: String
    public let colorName: String

    public nonisolated init(symbol: String, colorName: String) {
        self.symbol = symbol
        self.colorName = colorName
    }
}

enum MerchantCategoryAvatarFallback {
    nonisolated static func style(
        for record: ExpenseRecord,
        categoryRecords: [ExpenseCategoryRecord] = []
    ) -> MerchantCategoryAvatarStyle {
        if let categoryId = record.categoryId,
           let custom = categoryRecords.first(where: { $0.id == categoryId }) {
            return MerchantCategoryAvatarStyle(symbol: custom.icon, colorName: custom.color)
        }
        let raw = record.transactionCategory
        if let def = ExpenseCategoryCatalog.systemDefinitions.first(where: { $0.0 == raw }) {
            return MerchantCategoryAvatarStyle(symbol: def.icon, colorName: def.color)
        }
        return MerchantCategoryAvatarStyle(symbol: "bag.fill", colorName: "gray")
    }

    nonisolated static func style(for category: TransactionCategory) -> MerchantCategoryAvatarStyle {
        if let def = ExpenseCategoryCatalog.systemDefinitions.first(where: { $0.0 == category }) {
            return MerchantCategoryAvatarStyle(symbol: def.icon, colorName: def.color)
        }
        return MerchantCategoryAvatarStyle(symbol: "bag.fill", colorName: "gray")
    }
}
