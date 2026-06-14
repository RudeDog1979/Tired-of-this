//
//  DebtEngine.swift
//  BuxMuse
//  Features/Debt/
//
//  Central orchestrator for consumer debt tracking.
//

import Foundation
import Combine

@MainActor
public final class DebtEngine: ObservableObject {

    @Published public private(set) var debts: [Debt] = []

    private let persistence: PersistenceController
    private var saveWorkItem: DispatchWorkItem?

    public init(persistence: PersistenceController) {
        self.persistence = persistence
        load()
    }

    public var activeDebts: [Debt] {
        debts.filter { !$0.isArchived }
    }

    public var archivedDebts: [Debt] {
        debts.filter(\.isArchived)
    }

    public var totalOwed: Decimal {
        activeDebts.reduce(0) { $0 + $1.currentBalance }
    }

    public var paidThisMonth: Decimal {
        activeDebts.reduce(0) { $0 + $1.paidThisMonth }
    }

    public var nextDueDate: Date? {
        activeDebts.compactMap(\.nextDueDate).min()
    }

    /// Active debt balances sorted largest-first — for charts and breakdowns.
    public var balanceBreakdown: [(name: String, amount: Double)] {
        activeDebts
            .map { debt in
                (name: debt.name, amount: NSDecimalNumber(decimal: debt.currentBalance).doubleValue)
            }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Load / save

    public func load() {
        do {
            debts = try persistence.fetchAllDebts()
            Task { await DebtReminderScheduler.rescheduleAll(debts: debts) }
        } catch {
            print("Debt load failed: \(error)")
            debts = []
        }
    }

    public func replaceAllDebtsFromSync(_ synced: [Debt]) {
        saveWorkItem?.cancel()
        debts = synced
        objectWillChange.send()
        do {
            try persistence.replaceAllDebts(synced)
        } catch {
            print("Debt sync save failed: \(error)")
        }
    }

    private func notifyChanged() {
        objectWillChange.send()
        scheduleSave()
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = debts
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                try self.persistence.replaceAllDebts(snapshot)
                PersonalCloudSyncEngine.shared.pushDebtsIfNeeded(snapshot)
                Task { await DebtReminderScheduler.rescheduleAll(debts: snapshot) }
            } catch {
                print("Debt save failed: \(error)")
            }
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // MARK: - CRUD

    @discardableResult
    public func createDebt(
        name: String,
        type: DebtType = .other,
        currentBalance: Decimal,
        originalBalance: Decimal? = nil,
        aprPercent: Decimal? = nil,
        minimumPayment: Decimal? = nil,
        dueDayOfMonth: Int? = nil,
        lender: String? = nil,
        lenderSource: DebtLenderSource = .bank,
        remindersEnabled: Bool = true,
        notes: String? = nil
    ) -> Debt {
        let debt = Debt(
            name: name,
            type: type,
            currentBalance: currentBalance,
            originalBalance: originalBalance,
            aprPercent: aprPercent,
            minimumPayment: minimumPayment,
            dueDayOfMonth: dueDayOfMonth,
            lender: lender,
            lenderSource: lenderSource,
            remindersEnabled: remindersEnabled,
            notes: notes
        )
        debts.append(debt)
        notifyChanged()
        return debt
    }

    public func updateDebt(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[index] = debt
        notifyChanged()
    }

    public func deleteDebt(id: UUID) {
        debts.removeAll { $0.id == id }
        notifyChanged()
    }

    public func archiveDebt(id: UUID) {
        guard let index = debts.firstIndex(where: { $0.id == id }) else { return }
        debts[index].isArchived = true
        notifyChanged()
    }

    public func unarchiveDebt(id: UUID) {
        guard let index = debts.firstIndex(where: { $0.id == id }) else { return }
        debts[index].isArchived = false
        notifyChanged()
    }

    public func setRemindersEnabled(debtId: UUID, enabled: Bool) {
        guard let index = debts.firstIndex(where: { $0.id == debtId }) else { return }
        debts[index].remindersEnabled = enabled
        notifyChanged()
    }

    // MARK: - Payments

    public func recordPayment(
        debtId: UUID,
        amount: Decimal,
        date: Date = Date(),
        notes: String? = nil,
        linkedExpenseId: UUID? = nil
    ) {
        guard let index = debts.firstIndex(where: { $0.id == debtId }) else { return }
        let payment = DebtPayment(amount: amount, date: date, notes: notes, linkedExpenseId: linkedExpenseId)
        debts[index].payments.insert(payment, at: 0)
        debts[index].currentBalance = max(0, debts[index].currentBalance - amount)
        notifyChanged()
    }

    public func linkPaymentToExpense(debtId: UUID, paymentId: UUID, expenseId: UUID?) {
        guard let debtIndex = debts.firstIndex(where: { $0.id == debtId }),
              let paymentIndex = debts[debtIndex].payments.firstIndex(where: { $0.id == paymentId }) else { return }
        debts[debtIndex].payments[paymentIndex].linkedExpenseId = expenseId
        notifyChanged()
    }
}
