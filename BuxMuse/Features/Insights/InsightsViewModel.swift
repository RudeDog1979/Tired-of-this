//
//  InsightsViewModel.swift
//  BuxMuse
//  Features/Insights/
//
//  ViewModel for the BuxMuse Insights Engine.
//

import Foundation
import SwiftUI
import Combine

public final class InsightsViewModel: ObservableObject {
    @Published public var rankedInsights: [FinancialInsight] = []
    @Published public var selectedInsight: FinancialInsight? = nil
    @Published public var showInsightDetail: Bool = false
    
    private let insightsEngine: InsightsEngine
    private let financialEngine: FinancialIntelligenceEngine
    private let goalsViewModel: GoalsViewModel
    private var cancellables = Set<AnyCancellable>()
    
    public init(insightsEngine: InsightsEngine, financialEngine: FinancialIntelligenceEngine, goalsViewModel: GoalsViewModel) {
        self.insightsEngine = insightsEngine
        self.financialEngine = financialEngine
        self.goalsViewModel = goalsViewModel
        
        // Observe insights from insightsEngine
        insightsEngine.$insights
            .receive(on: RunLoop.main)
            .sink { [weak self] updated in
                self?.rankedInsights = updated
            }
            .store(in: &cancellables)
            
        // Observe changes in transactions to trigger automatic updates
        if let obsEngine = financialEngine as? LocalFinancialIntelligenceEngine18 {
            obsEngine.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.recalculate()
                }
                .store(in: &cancellables)
        }

        NotificationCenter.default.publisher(for: .buxMuseFinancialDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recalculate()
            }
            .store(in: &cancellables)
        
        // Observe changes in goals to trigger updates
        goalsViewModel.$goals
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recalculate()
            }
            .store(in: &cancellables)
            
        // Initial run
        recalculate()
    }
    
    public func recalculate() {
        let txs = financialEngine.allTransactions()
        let subs = financialEngine.activeSubscriptions()
        let gls = goalsViewModel.goals
        
        insightsEngine.recalculateAllInsightsAsync(
            transactions: txs,
            subscriptions: subs,
            goals: gls,
            goalsViewModel: goalsViewModel
        )
    }
    
    public func selectInsight(_ insight: FinancialInsight) {
        self.selectedInsight = insight
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            showInsightDetail = true
        }
    }
    
    public func dismissInsightDetail() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            showInsightDetail = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self = self else { return }
            if !self.showInsightDetail {
                self.selectedInsight = nil
            }
        }
    }
}
