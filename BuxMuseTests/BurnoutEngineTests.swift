//
//  BurnoutEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

@MainActor
final class BurnoutEngineTests: XCTestCase {
    var settings: SettingsStore!
    var engine: BurnoutEngine!
    
    override func setUp() {
        super.setUp()
        settings = SettingsStore.shared
        settings.resetAllData()
        engine = BurnoutEngine.shared
    }
    
    override func tearDown() {
        settings = nil
        engine = nil
        super.tearDown()
    }
    
    func testBurnoutCalculationWithHealthyProfile() async {
        // Healthy setup: 8 hours sleep, 3.0 stress level (low)
        settings.manualSleepHours = 8.0
        settings.manualStressLevel = 3.0
        
        let projects: [StudioProject] = [
            StudioProject(
                name: "Relaxed Gig",
                timeEntries: [
                    StudioTimeEntry(projectId: UUID(), startTime: Date().addingTimeInterval(-3600), endTime: Date(), notes: "1 hour worked")
                ]
            )
        ]
        let transactions: [Transaction] = []
        
        await engine.recalculate(projects: projects, transactions: transactions, settings: settings)
        
        let status = engine.currentStatus
        XCTAssertEqual(status.workHours, 1.0, accuracy: 0.05)
        XCTAssertEqual(status.sleepHours, 8.0)
        XCTAssertEqual(status.stressLevel, 3.0)
        XCTAssertEqual(status.stressExpenseCount, 0)
        
        // Stress index should be very low since load is minimal
        XCTAssertLessThan(status.stressIndex, 0.1)
        XCTAssertGreaterThan(status.creativeEnergyPercent, 90.0)
    }
    
    func testBurnoutCalculationWithBurnoutProfile() async {
        // High stress setup: 5 hours sleep (deprived), 9.0 stress level (extreme)
        settings.manualSleepHours = 5.0
        settings.manualStressLevel = 9.0
        
        let calendar = Calendar.current
        let now = Date()
        let projectID = UUID()
        
        // Log 50 hours of work this week
        var timeEntries: [StudioTimeEntry] = []
        for i in 0..<5 {
            let start = calendar.date(byAdding: .day, value: -i, to: now)!
            let end = start.addingTimeInterval(10 * 3600) // 10 hours worked each day
            timeEntries.append(StudioTimeEntry(projectId: projectID, startTime: start, endTime: end, notes: "Hard labor"))
        }
        
        let projects = [
            StudioProject(name: "High Intensity Grind", timeEntries: timeEntries)
        ]
        
        // 3 stress-tagged transactions
        let txs = [
            Transaction(date: now, amount: MoneyAmount(value: -150, currencyCode: "USD"), merchantName: "Therapist", category: .other, emotion: "Highly Stressed"),
            Transaction(date: now, amount: MoneyAmount(value: -200, currencyCode: "USD"), merchantName: "Coffee Shop", category: .other, emotion: "Overwhelmed with work"),
            Transaction(date: now, amount: MoneyAmount(value: -50, currencyCode: "USD"), merchantName: "Pharmacy", category: .other, emotion: "Anxious and tired"),
            Transaction(date: now, amount: MoneyAmount(value: -10, currencyCode: "USD"), merchantName: "Normal Store", category: .other, emotion: "Happy") // Non-stress
        ]
        
        await engine.recalculate(projects: projects, transactions: txs, settings: settings)
        
        let status = engine.currentStatus
        XCTAssertEqual(status.workHours, 50.0, accuracy: 0.1)
        XCTAssertEqual(status.sleepHours, 5.0)
        XCTAssertEqual(status.stressLevel, 9.0)
        XCTAssertEqual(status.stressExpenseCount, 3)
        
        // Stress index should be highly elevated, creative energy severely depleted
        XCTAssertGreaterThan(status.stressIndex, 0.8)
        XCTAssertLessThan(status.creativeEnergyPercent, 50.0)
    }
}
