//
//  ExpenseSheetMode.swift
//  BuxMuse
//

import Foundation

enum ExpenseSheetMode: Identifiable, Equatable {
    case add
    case addIncome
    case addWithCategoryFocus
    case addWithAutoScan
    case edit(Transaction)
    case editWithCategorySplit(Transaction)

    var id: String {
        switch self {
        case .add: return "add"
        case .addIncome: return "addIncome"
        case .addWithCategoryFocus: return "addWithCategoryFocus"
        case .addWithAutoScan: return "addWithAutoScan"
        case .edit(let tx): return tx.id.uuidString
        case .editWithCategorySplit(let tx): return "split-\(tx.id.uuidString)"
        }
    }

    var editingTransaction: Transaction? {
        switch self {
        case .edit(let tx), .editWithCategorySplit(let tx):
            return tx
        default:
            return nil
        }
    }

    var opensWithCategorySplit: Bool {
        if case .editWithCategorySplit = self { return true }
        return false
    }
}
