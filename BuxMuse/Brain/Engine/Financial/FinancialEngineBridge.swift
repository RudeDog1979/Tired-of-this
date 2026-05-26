//
//  FinancialEngineBridge.swift
//  BuxMuse
//
//  ObservableObject bridge for FinancialIntelligenceEngine (iOS 18 + 26).
//

import Foundation
import Combine

@MainActor
public final class FinancialEngineBridge: ObservableObject {
    public let engine: FinancialIntelligenceEngine
    private var cancellables = Set<AnyCancellable>()

    public init(engine: FinancialIntelligenceEngine) {
        self.engine = engine
        wireChangeNotifications()
    }

    private func wireChangeNotifications() {
        if let engine18 = engine as? LocalFinancialIntelligenceEngine18 {
            engine18.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                    self?.engine18DidChange()
                }
                .store(in: &cancellables)
        }

        if #available(iOS 26, *) {
            if let engine26 = engine as? LocalFinancialIntelligenceEngine {
                engine26.onDataChanged = { [weak self] in
                    Task { @MainActor in
                        self?.objectWillChange.send()
                        self?.engine18DidChange()
                    }
                }
            }
        }
    }

    /// Called by Brain after wiring; duplicated name for both engines.
    private func engine18DidChange() {
        NotificationCenter.default.post(name: .buxMuseFinancialDataDidChange, object: nil)
    }

    // MARK: - Forwarding

    public func addTransaction(_ transaction: Transaction) {
        engine.addTransaction(transaction)
    }

    public func updateTransaction(_ transaction: Transaction) {
        engine.updateTransaction(transaction)
    }

    public func deleteTransaction(id: UUID) {
        engine.deleteTransaction(id: id)
    }

    public func allTransactions() -> [Transaction] { engine.allTransactions() }
    public func categorySummaries(for range: DateInterval) -> [CategorySummary] { engine.categorySummaries(for: range) }
    public func overspendAlerts(for range: DateInterval) -> [OverspendAlert] { engine.overspendAlerts(for: range) }
    public func savingsOpportunities(for range: DateInterval) -> [SavingsOpportunity] { engine.savingsOpportunities(for: range) }
    public func merchantClusters() -> [MerchantCluster] { engine.merchantClusters() }
    public func activeSubscriptions() -> [SubscriptionInfo] { engine.activeSubscriptions() }
    public func subscriptionDetail(for merchantName: String) -> SubscriptionDetail? { engine.subscriptionDetail(for: merchantName) }
}

extension Notification.Name {
    static let buxMuseFinancialDataDidChange = Notification.Name("BuxMuseFinancialDataDidChange")
}
