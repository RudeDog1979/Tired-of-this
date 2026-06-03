//
//  GoalsEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Central orchestrator for the local-first financial goals engine.
//

import Foundation
import Combine

public final class GoalsEngine: ObservableObject {
    
    @Published public private(set) var goals: [Goal] = []
    
    private var cachedProjections: [UUID: GoalProjection] = [:]
    private var cachedRisks: [UUID: [GoalRisk]] = [:]
    private var cachedOpportunities: [UUID: [GoalOpportunity]] = [:]
    private var cachedMomentum: [UUID: GoalMomentumResult] = [:]
    private var cachedHealth: [UUID: GoalHealth] = [:]
    private var cachedTimelines: [UUID: GoalsTimelineAIResult] = [:]
    
    private let calculationQueue = DispatchQueue(label: "com.buxmuse.goals.calculations", qos: .userInitiated)
    
    private let projectionEngine = GoalsProjectionEngine()
    private let riskEngine = GoalsRiskEngine()
    private let opportunityEngine = GoalsOpportunityEngine()
    private let momentumEngine = GoalsMomentumEngine()
    private let healthEngine = GoalsHealthEngine()
    private let timelineAI = GoalsTimelineAI()
    
    public init() {
        self.goals = []
    }

    public func replaceAllGoals(_ loaded: [Goal]) {
        goals = loaded
        invalidateCaches()
        objectWillChange.send()
    }

    private func notifyChanged() {
        invalidateCaches()
        objectWillChange.send()
    }
    
    // MARK: - CRUD Operations
    
    public func createGoal(
        name: String,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        deadline: Date? = nil,
        priority: Int = 2,
        notes: String? = nil
    ) -> Goal {
        let newGoal = Goal(
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            deadline: deadline,
            priority: priority,
            notes: notes
        )
        goals.append(newGoal)
        notifyChanged()
        return newGoal
    }
    
    public func updateGoal(_ goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            notifyChanged()
        }
    }
    
    public func deleteGoal(id: UUID) {
        goals.removeAll(where: { $0.id == id })
        notifyChanged()
    }
    
    public func addContribution(toGoalId id: UUID, amount: Decimal, notes: String? = nil) {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return }
        let contribution = GoalContribution(amount: amount, notes: notes)
        
        var updatedGoal = goals[index]
        updatedGoal.contributions.append(contribution)
        updatedGoal.currentAmount += amount
        
        goals[index] = updatedGoal
        notifyChanged()
    }
    
    public func adjustGoal(id: UUID, targetAmount: Decimal, deadline: Date?, priority: Int) {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return }
        var updatedGoal = goals[index]
        updatedGoal.targetAmount = targetAmount
        updatedGoal.deadline = deadline
        updatedGoal.priority = priority
        goals[index] = updatedGoal
        notifyChanged()
    }
    
    public func getBrainSuggestions(financialEngine: FinancialIntelligenceEngine) -> GoalSuggestions {
        let txs = financialEngine.allTransactions()
        let now = Date()
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let recentTxs = txs.filter { $0.date >= thirtyDaysAgo }
        
        let monthlyIncome = recentTxs.filter { $0.category == .income }.reduce(Decimal(0)) { $0 + $1.amount.value }
        let monthlyExpenses = recentTxs.filter { $0.category != .income }.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
        let netSavingsRate = max(0, monthlyIncome - monthlyExpenses)
        
        // Target: 6 months of FCF or default £5,000
        let target = netSavingsRate > 0 ? (netSavingsRate * 6) : 5000
        
        // Deadline: 6 months from now
        let deadline = calendar.date(byAdding: .month, value: 6, to: now) ?? now
        
        // Priority: high if no high priority goals, else medium (2)
        let priority = goals.contains(where: { $0.priority == 1 }) ? 2 : 1
        
        // Cadence: Monthly default
        let schedule = "Monthly"
        
        return GoalSuggestions(
            suggestedTargetAmount: target,
            suggestedDeadline: deadline,
            suggestedPriority: priority,
            suggestedContributionSchedule: schedule
        )
    }
    
    // MARK: - Intelligence Sub-Engine Accessors
    
    public func getProjection(forGoalId id: UUID, financialEngine: FinancialIntelligenceEngine) -> GoalProjection? {
        if let cached = cachedProjections[id] { return cached }
        // Fallback synchronous calculate if cache not ready yet
        guard let goal = goals.first(where: { $0.id == id }) else { return nil }
        return projectionEngine.project(
            goal: goal,
            transactions: financialEngine.allTransactions(),
            activeSubscriptions: financialEngine.activeSubscriptions()
        )
    }
    
    public func getRisks(forGoalId id: UUID, financialEngine: FinancialIntelligenceEngine) -> [GoalRisk] {
        if let cached = cachedRisks[id] { return cached }
        // Fallback synchronous calculate
        guard let goal = goals.first(where: { $0.id == id }) else { return [] }
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let range = DateInterval(start: thirtyDaysAgo, end: now)
        return riskEngine.analyzeRisks(
            goal: goal,
            transactions: financialEngine.allTransactions(),
            activeSubscriptions: financialEngine.activeSubscriptions(),
            overspendAlerts: financialEngine.overspendAlerts(for: range),
            locale: BuxInterfaceLocale.currentInterfaceLocale
        )
    }
    
    public func getOpportunities(forGoalId id: UUID, financialEngine: FinancialIntelligenceEngine) -> [GoalOpportunity] {
        if let cached = cachedOpportunities[id] { return cached }
        // Fallback synchronous calculate
        guard let goal = goals.first(where: { $0.id == id }) else { return [] }
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let range = DateInterval(start: thirtyDaysAgo, end: now)
        return opportunityEngine.findOpportunities(
            goal: goal,
            transactions: financialEngine.allTransactions(),
            activeSubscriptions: financialEngine.activeSubscriptions(),
            savingsOpportunities: financialEngine.savingsOpportunities(for: range),
            locale: BuxInterfaceLocale.currentInterfaceLocale
        )
    }
    
    public func getMomentum(forGoalId id: UUID) -> GoalMomentumResult? {
        if let cached = cachedMomentum[id] { return cached }
        guard let goal = goals.first(where: { $0.id == id }) else { return nil }
        return momentumEngine.computeMomentum(
            goal: goal,
            locale: BuxInterfaceLocale.currentInterfaceLocale
        )
    }
    
    public func getHealth(forGoalId id: UUID, financialEngine: FinancialIntelligenceEngine) -> GoalHealth? {
        if let cached = cachedHealth[id] { return cached }
        // Fallback synchronous calculate
        guard let goal = goals.first(where: { $0.id == id }) else { return nil }
        let risks = getRisks(forGoalId: id, financialEngine: financialEngine)
        let momentum = getMomentum(forGoalId: id)?.score ?? 0.0
        return healthEngine.evaluateHealth(goal: goal, risks: risks, momentumScore: momentum)
    }
    
    public func getTimelineAI(forGoalId id: UUID, financialEngine: FinancialIntelligenceEngine) -> GoalsTimelineAIResult? {
        if let cached = cachedTimelines[id] { return cached }
        // Fallback synchronous calculate
        guard let goal = goals.first(where: { $0.id == id }) else { return nil }
        guard let projection = getProjection(forGoalId: id, financialEngine: financialEngine) else { return nil }
        let risks = getRisks(forGoalId: id, financialEngine: financialEngine)
        let opportunities = getOpportunities(forGoalId: id, financialEngine: financialEngine)
        return timelineAI.analyzeTimeline(
            goal: goal,
            projection: projection,
            risks: risks,
            opportunities: opportunities,
            locale: BuxInterfaceLocale.currentInterfaceLocale
        )
    }
    
    // MARK: - Asynchronous Pre-calculations
    
    public func precalculateAllGoalsAsync(financialEngine: FinancialIntelligenceEngine) {
        let goalsSnapshot = goals
        let txs = financialEngine.allTransactions()
        let subs = financialEngine.activeSubscriptions()
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let range = DateInterval(start: thirtyDaysAgo, end: now)
        let overspendAlerts = financialEngine.overspendAlerts(for: range)
        let savingsOpportunities = financialEngine.savingsOpportunities(for: range)
        
        let locale = BuxInterfaceLocale.currentInterfaceLocale

        calculationQueue.async { [weak self] in
            guard let self = self else { return }
            
            var projections: [UUID: GoalProjection] = [:]
            var risks: [UUID: [GoalRisk]] = [:]
            var opportunities: [UUID: [GoalOpportunity]] = [:]
            var momentum: [UUID: GoalMomentumResult] = [:]
            var health: [UUID: GoalHealth] = [:]
            var timelines: [UUID: GoalsTimelineAIResult] = [:]
            
            for goal in goalsSnapshot {
                let proj = self.projectionEngine.project(
                    goal: goal,
                    transactions: txs,
                    activeSubscriptions: subs
                )
                projections[goal.id] = proj
                
                let rsk = self.riskEngine.analyzeRisks(
                    goal: goal,
                    transactions: txs,
                    activeSubscriptions: subs,
                    overspendAlerts: overspendAlerts,
                    locale: locale
                )
                risks[goal.id] = rsk
                
                let opp = self.opportunityEngine.findOpportunities(
                    goal: goal,
                    transactions: txs,
                    activeSubscriptions: subs,
                    savingsOpportunities: savingsOpportunities,
                    locale: locale
                )
                opportunities[goal.id] = opp
                
                let mom = self.momentumEngine.computeMomentum(goal: goal, locale: locale)
                momentum[goal.id] = mom
                
                let hlt = self.healthEngine.evaluateHealth(goal: goal, risks: rsk, momentumScore: mom.score)
                health[goal.id] = hlt
                
                let tml = self.timelineAI.analyzeTimeline(
                    goal: goal,
                    projection: proj,
                    risks: rsk,
                    opportunities: opp,
                    locale: locale
                )
                timelines[goal.id] = tml
            }
            
            DispatchQueue.main.async {
                self.cachedProjections = projections
                self.cachedRisks = risks
                self.cachedOpportunities = opportunities
                self.cachedMomentum = momentum
                self.cachedHealth = health
                self.cachedTimelines = timelines
                self.objectWillChange.send()
            }
        }
    }

    /// Clears precomputed goal intelligence (e.g. after Country/Region changes).
    public func invalidateLocalizedCaches(andRecalculate financialEngine: FinancialIntelligenceEngine) {
        invalidateCaches()
        precalculateAllGoalsAsync(financialEngine: financialEngine)
    }

    private func invalidateCaches() {
        cachedProjections.removeAll()
        cachedRisks.removeAll()
        cachedOpportunities.removeAll()
        cachedMomentum.removeAll()
        cachedHealth.removeAll()
        cachedTimelines.removeAll()
    }
}
