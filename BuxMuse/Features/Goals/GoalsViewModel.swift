//
//  GoalsViewModel.swift
//  BuxMuse
//  Features/Goals/
//
//  ViewModel representing UI states and exposing calculations directly from sub-engines.
//

import Foundation
import SwiftUI
import Combine

public final class GoalsViewModel: ObservableObject {
    
    @Published public var goals: [Goal] = []
    @Published public var selectedGoalDetail: GoalDetailState? = nil
    
    private let goalsEngine: GoalsEngine
    private let financialEngine: FinancialIntelligenceEngine
    private var cancellables = Set<AnyCancellable>()
    
    public struct GoalDetailState: Identifiable {
        public var id: UUID { goal.id }
        public let goal: Goal
        public let projection: GoalProjection
        public let risks: [GoalRisk]
        public let opportunities: [GoalOpportunity]
        public let momentum: GoalMomentumResult
        public let health: GoalHealth
        public let timelineAI: GoalsTimelineAIResult
        
        // Flat, pre-computed properties to run 120 FPS inside the transition view
        public let sortedContributions: [GoalContribution]
        public let progress: Double
        public let normalizedScore: Double
    }
    
    public init(goalsEngine: GoalsEngine, financialEngine: FinancialIntelligenceEngine) {
        self.goalsEngine = goalsEngine
        self.financialEngine = financialEngine
        
        // Observe goals changes from the goalsEngine
        goalsEngine.$goals
            .sink { [weak self] updatedGoals in
                guard let self = self else { return }
                self.goals = updatedGoals
                self.goalsEngine.precalculateAllGoalsAsync(financialEngine: self.financialEngine)
                self.updateSelectedGoalDetailIfNeeded()
            }
            .store(in: &cancellables)
            
        // Observe transactions / subscriptions changes from financialEngine
        if let obsEngine = financialEngine as? LocalFinancialIntelligenceEngine18 {
            obsEngine.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.goalsEngine.precalculateAllGoalsAsync(financialEngine: self.financialEngine)
                }
                .store(in: &cancellables)
        }

        NotificationCenter.default.publisher(for: .buxMuseFinancialDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.goalsEngine.precalculateAllGoalsAsync(financialEngine: self.financialEngine)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    public func selectGoal(_ goal: Goal) {
        self.selectedGoalDetail = buildDetailState(for: goal)
    }
    
    public func clearSelection() {
        self.selectedGoalDetail = nil
    }
    
    public func addContribution(toGoalId id: UUID, amount: Decimal, notes: String?) {
        goalsEngine.addContribution(toGoalId: id, amount: amount, notes: notes)
    }
    
    public func createGoal(name: String, targetAmount: Decimal, currentAmount: Decimal, deadline: Date?, priority: Int, notes: String?) {
        _ = goalsEngine.createGoal(name: name, targetAmount: targetAmount, currentAmount: currentAmount, deadline: deadline, priority: priority, notes: notes)
    }
    
    public func deleteGoal(id: UUID) {
        goalsEngine.deleteGoal(id: id)
        if selectedGoalDetail?.goal.id == id {
            clearSelection()
        }
    }
    
    public func updateGoal(id: UUID, name: String, targetAmount: Decimal, deadline: Date?, priority: Int, notes: String?) {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return }
        var updated = goals[index]
        updated.name = name
        updated.targetAmount = targetAmount
        updated.deadline = deadline
        updated.priority = priority
        updated.notes = notes
        goalsEngine.updateGoal(updated)
    }
    
    public func adjustGoal(id: UUID, targetAmount: Decimal, deadline: Date?, priority: Int) {
        goalsEngine.adjustGoal(id: id, targetAmount: targetAmount, deadline: deadline, priority: priority)
    }
    
    public func getBrainSuggestions() -> GoalSuggestions {
        return goalsEngine.getBrainSuggestions(financialEngine: financialEngine)
    }
    
    // MARK: - Detail State Construction
    
    public func buildDetailState(for goal: Goal) -> GoalDetailState {
        let projection = goalsEngine.getProjection(forGoalId: goal.id, financialEngine: financialEngine) ?? GoalProjection(
            expectedCompletionDate: Date().addingTimeInterval(30 * 86400),
            bestCaseDate: Date().addingTimeInterval(20 * 86400),
            worstCaseDate: Date().addingTimeInterval(45 * 86400),
            recommendedContribution: goal.targetAmount / 10,
            contributionSchedule: "Monthly"
        )
        let risks = goalsEngine.getRisks(forGoalId: goal.id, financialEngine: financialEngine)
        let opportunities = goalsEngine.getOpportunities(forGoalId: goal.id, financialEngine: financialEngine)
        let momentum = goalsEngine.getMomentum(forGoalId: goal.id) ?? GoalMomentumResult(
            score: 0.0,
            statusDescription: "Consistent Momentum",
            microActions: [],
            habitActions: []
        )
        let health = goalsEngine.getHealth(forGoalId: goal.id, financialEngine: financialEngine) ?? GoalHealth(
            score: 75,
            riskFactors: [],
            momentum: 0.0
        )
        let timeline = goalsEngine.getTimelineAI(forGoalId: goal.id, financialEngine: financialEngine) ?? GoalsTimelineAIResult(
            expectedCompletionDate: projection.expectedCompletionDate,
            delayRisk: "Low",
            accelerationPotentialMonths: 0.0,
            scenarios: [],
            actionableInsight: "Save regularly to achieve your goal."
        )
        
        let sorted = goal.contributions.sorted(by: { $0.date > $1.date })
        let progress = min(1.0, max(0.0, Double(NSDecimalNumber(decimal: goal.currentAmount).doubleValue / max(1.0, NSDecimalNumber(decimal: goal.targetAmount).doubleValue))))
        let normScore = (momentum.score + 1.0) / 2.0
        
        return GoalDetailState(
            goal: goal,
            projection: projection,
            risks: risks,
            opportunities: opportunities,
            momentum: momentum,
            health: health,
            timelineAI: timeline,
            sortedContributions: sorted,
            progress: progress,
            normalizedScore: normScore
        )
    }
    
    private func updateSelectedGoalDetailIfNeeded() {
        if let currentDetail = selectedGoalDetail,
           let updatedGoal = goals.first(where: { $0.id == currentDetail.goal.id }) {
            self.selectedGoalDetail = buildDetailState(for: updatedGoal)
        }
    }
}
