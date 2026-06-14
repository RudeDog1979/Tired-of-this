//
//  DebtPersistence.swift
//  BuxMuse
//
//  SwiftData persistence for consumer debts.
//

import Foundation
import SwiftData

extension PersistenceController {

    func fetchAllDebts() throws -> [Debt] {
        let descriptor = FetchDescriptor<DebtEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).map { $0.toDebt() }
    }

    func replaceAllDebts(_ debts: [Debt]) throws {
        let existing = try context.fetch(FetchDescriptor<DebtEntity>())
        existing.forEach { context.delete($0) }
        for debt in debts {
            context.insert(DebtEntity.from(debt))
        }
        try context.save()
    }

    func fetchAllDebtEntities() throws -> [DebtEntity] {
        try context.fetch(FetchDescriptor<DebtEntity>())
    }
}
