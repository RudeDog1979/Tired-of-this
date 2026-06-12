//
//  GoalsEngineTests.swift
//  BuxMuseTests
//
//  Unit tests verifying the BuxMuse Goals Engine, Projection Engine, Risk Engine,
//  Opportunity Engine, Momentum Engine, Health Engine, and Timeline AI.
//

import XCTest
@testable import BuxMuse

final class GoalsEngineTests: XCTestCase {
    var financialEngine: LocalFinancialIntelligenceEngine18!
    var goalsEngine: GoalsEngine!
    var viewModel: GoalsViewModel!
    
    override func setUp() {
        super.setUp()
        financialEngine = LocalFinancialIntelligenceEngine18()
        goalsEngine = GoalsEngine()
        viewModel = GoalsViewModel(goalsEngine: goalsEngine, financialEngine: financialEngine)
    }
    
    override func tearDown() {
        viewModel = nil
        goalsEngine = nil
        financialEngine = nil
        super.tearDown()
    }
    
    func testGoalsCrudAndContributionTracking() {
        let name = "Test Vacation"
        let target: Decimal = 5000
        let initial: Decimal = 1000
        
        let newGoal = goalsEngine.createGoal(
            name: name,
            targetAmount: target,
            currentAmount: initial,
            deadline: Date().addingTimeInterval(180 * 86400),
            priority: 2,
            notes: "Summertime trip"
        )
        
        XCTAssertEqual(newGoal.name, name)
        XCTAssertEqual(newGoal.targetAmount, target)
        XCTAssertEqual(newGoal.currentAmount, initial)
        
        // Add contribution
        goalsEngine.addContribution(toGoalId: newGoal.id, amount: 500, notes: "Weekly deposit")
        
        guard let updatedGoal = goalsEngine.goals.first(where: { $0.id == newGoal.id }) else {
            XCTFail("Goal not found in engine")
            return
        }
        
        XCTAssertEqual(updatedGoal.currentAmount, 1500)
        XCTAssertEqual(updatedGoal.contributions.count, 1)
        XCTAssertEqual(updatedGoal.contributions.first?.amount, 500)
        
        // Delete goal
        goalsEngine.deleteGoal(id: newGoal.id)
        XCTAssertFalse(goalsEngine.goals.contains(where: { $0.id == newGoal.id }))
    }
    
    func testProjectionEngineDatesAndSavingsRate() {
        let calendar = Calendar.current
        let today = Date()
        let deadline = calendar.date(byAdding: .month, value: 12, to: today)
        
        let goal = Goal(
            name: "Graduation Fund",
            targetAmount: 12000,
            currentAmount: 2000,
            deadline: deadline,
            priority: 2,
            createdAt: today,
            contributions: [
                GoalContribution(amount: 1000, date: calendar.date(byAdding: .day, value: -30, to: today)!, notes: "Deposit 1"),
                GoalContribution(amount: 1000, date: today, notes: "Deposit 2")
            ]
        )
        
        let projectionEngine = GoalsProjectionEngine()
        let projection = projectionEngine.project(
            goal: goal,
            transactions: [],
            activeSubscriptions: []
        )
        
        // Remaining amount is 10,000.
        // Direct contributions: 2,000 total over 30 days = roughly 2,000/month.
        // Expected Completion: remaining (10k) / monthly (2k) = 5 months from now.
        let daysToExpected = projection.expectedCompletionDate.timeIntervalSince(today) / 86400.0
        XCTAssertTrue(daysToExpected > 130 && daysToExpected < 170) // roughly 150 days
        
        // Recommended Contribution to achieve goal by deadline (12 months left):
        // Remaining (10,000) / 12 months = ~833.33
        XCTAssertEqual(round(NSDecimalNumber(decimal: projection.recommendedContribution).doubleValue), 833.0)
    }
    
    func testRiskEngineDetections() {
        let calendar = Calendar.current
        let today = Date()
        let deadline = calendar.date(byAdding: .month, value: 3, to: today) // 3 months deadline
        
        // Goal requires 10,000 remaining in 3 months = ~3,333/month.
        // But user is only contributing 500/month.
        let goal = Goal(
            name: "Downpayment",
            targetAmount: 15000,
            currentAmount: 5000,
            deadline: deadline,
            priority: 1,
            createdAt: calendar.date(byAdding: .month, value: -1, to: today)!,
            contributions: [
                GoalContribution(amount: 500, date: calendar.date(byAdding: .day, value: -15, to: today)!, notes: "Small deposit")
            ]
        )
        
        // High subscription burn transactions
        let tx1 = Transaction(date: today, amount: MoneyAmount(value: -200, currencyCode: "USD"), merchantName: "Overhead", category: .subscriptions)
        let activeSubs = [SubscriptionInfo(merchantName: "Overhead", cost: MoneyAmount(value: -200, currencyCode: "USD"), billingCycle: .monthly, nextRenewalDate: today, category: .subscriptions)]
        
        let riskEngine = GoalsRiskEngine()
        let risks = riskEngine.analyzeRisks(
            goal: goal,
            transactions: [tx1],
            activeSubscriptions: activeSubs,
            overspendAlerts: [OverspendAlert(category: .groceries, currentTotal: MoneyAmount(value: -800, currencyCode: "USD"), baselineTotal: MoneyAmount(value: -400, currencyCode: "USD"), overspendPercentage: 100.0)]
        )
        
        // Risks should flag:
        // 1. Falling Behind (expected completion after 3 months deadline)
        // 2. High subscription burn (> $150)
        // 3. Overspend threat (category spike in Groceries)
        XCTAssertTrue(risks.contains(where: { $0.type == GoalRiskType.fallingBehind }))
        XCTAssertTrue(risks.contains(where: { $0.type == GoalRiskType.subscriptionThreat }))
        XCTAssertTrue(risks.contains(where: { $0.type == GoalRiskType.overspendThreat }))
    }
    
    func testOpportunityAndMomentumEngines() {
        let calendar = Calendar.current
        let today = Date()
        
        let goal = Goal(
            name: "Tech Upgrade",
            targetAmount: 3000,
            currentAmount: 1500,
            deadline: calendar.date(byAdding: .month, value: 6, to: today),
            priority: 2,
            createdAt: calendar.date(byAdding: .day, value: -45, to: today)!,
            contributions: [
                GoalContribution(amount: 500, date: calendar.date(byAdding: .day, value: -40, to: today)!, notes: "Initial save"),
                GoalContribution(amount: 1000, date: calendar.date(byAdding: .day, value: -5, to: today)!, notes: "Big save")
            ]
        )
        
        // 1. Momentum Test
        let momentumEngine = GoalsMomentumEngine()
        let momentum = momentumEngine.computeMomentum(goal: goal)
        
        // User deposited $1,000 recently vs $500 earlier, showing accelerating velocity.
        XCTAssertTrue(momentum.score > 0.0)
        XCTAssertEqual(momentum.statusDescription, "Accelerating")
        XCTAssertFalse(momentum.microActions.isEmpty)
        
        // 2. Opportunity Test
        let opportunityEngine = GoalsOpportunityEngine()
        let activeSubs = [SubscriptionInfo(merchantName: "Adobe CC", cost: MoneyAmount(value: -50.0, currencyCode: "USD"), billingCycle: .monthly, nextRenewalDate: today, category: .subscriptions)]
        
        let opportunities = opportunityEngine.findOpportunities(
            goal: goal,
            transactions: [],
            activeSubscriptions: activeSubs,
            savingsOpportunities: []
        )
        
        // Opportunities should recommend cancelling Adobe CC to save money
        XCTAssertTrue(opportunities.contains(where: { $0.description.contains("Adobe CC") }))
    }
    
    func testHealthEngineAndTimelineAI() {
        let calendar = Calendar.current
        let today = Date()
        
        let goal = Goal(
            name: "Emergency Fund",
            targetAmount: 10000,
            currentAmount: 5000,
            priority: 1,
            createdAt: today
        )
        
        let healthEngine = GoalsHealthEngine()
        let activeRisks = [
            GoalRisk(type: .fallingBehind, description: "Delayed", severity: "high", suggestedFix: "Save more"),
            GoalRisk(type: .missedContribution, description: "Missed", severity: "medium", suggestedFix: "Automate")
        ]
        
        let health = healthEngine.evaluateHealth(goal: goal, risks: activeRisks, momentumScore: 0.5)
        
        // Health score: 100 - 20 (high risk) - 10 (medium risk) + 7 (momentum adjustment) = 77
        XCTAssertEqual(health.score, 77)
        XCTAssertEqual(health.stability, "medium")
        
        // Timeline AI
        let timelineAI = GoalsTimelineAI()
        let projection = GoalProjection(expectedCompletionDate: calendar.date(byAdding: .month, value: 8, to: today)!, bestCaseDate: today, worstCaseDate: today, recommendedContribution: 500, contributionSchedule: "Monthly")
        
        let result = timelineAI.analyzeTimeline(goal: goal, projection: projection, risks: activeRisks, opportunities: [])
        
        XCTAssertEqual(result.delayRisk, "High") // Due to active high risk
        XCTAssertEqual(result.scenarios.count, 3)
    }
}
