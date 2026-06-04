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

    var id: String {
        switch self {
        case .add: return "add"
        case .addIncome: return "addIncome"
        case .addWithCategoryFocus: return "addWithCategoryFocus"
        case .addWithAutoScan: return "addWithAutoScan"
        case .edit(let tx): return tx.id.uuidString
        }
    }
}
