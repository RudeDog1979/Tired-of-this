//
//  ExpenseSheetMode.swift
//  BuxMuse
//

import Foundation

enum ExpenseSheetMode: Identifiable, Equatable {
    case add
    case edit(Transaction)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let tx): return tx.id.uuidString
        }
    }
}
