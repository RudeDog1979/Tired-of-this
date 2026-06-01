//
//  BurnoutEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Local, deterministic, and HealthKit-integrated Burnout & Creative Energy tracker.
//

import Foundation
import HealthKit
import Combine

public struct BurnoutInsightData: Codable, Equatable {
    public var stressIndex: Double
    public var creativeEnergyPercent: Double
    public var workHours: Double
    public var sleepHours: Double
    public var stressLevel: Double // 1.0 to 10.0
    public var stressExpenseCount: Int
    
    public init(
        stressIndex: Double = 0.0,
        creativeEnergyPercent: Double = 100.0,
        workHours: Double = 0.0,
        sleepHours: Double = 8.0,
        stressLevel: Double = 5.0,
        stressExpenseCount: Int = 0
    ) {
        self.stressIndex = stressIndex
        self.creativeEnergyPercent = creativeEnergyPercent
        self.workHours = workHours
        self.sleepHours = sleepHours
        self.stressLevel = stressLevel
        self.stressExpenseCount = stressExpenseCount
    }
}

@MainActor
public final class BurnoutEngine: ObservableObject {
    public static let shared = BurnoutEngine()
    
    @Published public private(set) var currentStatus = BurnoutInsightData()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    /// Requests authorization for sleep analysis and HRV if needed.
    public func requestHealthKitAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil else {
            print("BurnoutEngine: NSHealthShareUsageDescription missing from Info.plist")
            return false
        }
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [sleepType]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            return true
        } catch {
            return false
        }
    }
    
    /// Recalculates stats using local project hours, emotions on transactions, and either HealthKit or SettingsStore manual overrides.
    public func recalculate(
        projects: [StudioProject],
        transactions: [Transaction],
        settings: SettingsStore
    ) async {
        let workHours = calculateTrackedHoursThisWeek(projects: projects)
        let stressExpenses = countStressExpensesThisWeek(transactions: transactions)
        
        var sleepHours = settings.manualSleepHours
        let stressLevel = settings.manualStressLevel
        
        // If HealthKit sync is active and authorized, query average sleep duration
        if settings.healthKitSyncEnabled,
           SettingsStore.shared.studioMode == .pro,
           HKHealthStore.isHealthDataAvailable() {
            if let queriedSleep = await fetchAverageSleepHoursThisWeek() {
                sleepHours = queriedSleep
            }
        }
        
        // Deterministic Burnout Index Calculation:
        // stressIndex represents systemic pressure: work intensity + financial anxiety tags weighted against rest.
        let sleepFactor = max(4.0, sleepHours)
        let workWeight = workHours * 1.3
        let expenseAnxietyWeight = Double(stressExpenses) * 3.0
        
        let totalLoad = workWeight + expenseAnxietyWeight
        let baselineCapacity = sleepFactor * 7.5 // Max capacity is driven by sleep quality
        let stressMultiplier = stressLevel / 5.0
        
        let rawIndex = (totalLoad / max(1.0, baselineCapacity)) * stressMultiplier
        let stressIndex = min(1.5, max(0.0, rawIndex))
        
        // Creative Energy is the inverse of stress, scaled out of 100%
        let creativeEnergyPercent = max(0.0, min(100.0, (1.0 - (stressIndex / 1.35)) * 100.0))
        
        self.currentStatus = BurnoutInsightData(
            stressIndex: stressIndex,
            creativeEnergyPercent: creativeEnergyPercent,
            workHours: workHours,
            sleepHours: sleepHours,
            stressLevel: stressLevel,
            stressExpenseCount: stressExpenses
        )
    }
    
    private func calculateTrackedHoursThisWeek(projects: [StudioProject]) -> Double {
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        var totalSecs: TimeInterval = 0
        for project in projects {
            for entry in project.timeEntries {
                if entry.startTime >= oneWeekAgo {
                    // Cap duration to verify date range
                    let start = max(entry.startTime, oneWeekAgo)
                    let end = entry.endTime
                    if end > start {
                        totalSecs += end.timeIntervalSince(start)
                    }
                }
            }
        }
        return totalSecs / 3600.0
    }
    
    private func countStressExpensesThisWeek(transactions: [Transaction]) -> Int {
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        var count = 0
        for tx in transactions {
            guard tx.date >= oneWeekAgo else { continue }
            if let emotion = tx.emotion?.lowercased() {
                if emotion.contains("stress") ||
                    emotion.contains("anxi") ||
                    emotion.contains("overwhelm") ||
                    emotion.contains("panic") ||
                    emotion.contains("frustrat") ||
                    emotion.contains("worr") {
                    count += 1
                }
            }
        }
        return count
    }
    
    /// Queries the HealthKit store for sleep analysis samples over the past week and averages the daily duration in hours.
    private func fetchAverageSleepHoursThisWeek() async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }
        
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: oneWeekAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil, let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Aggregate sleep analysis value samples representing actual rest time (.asleep)
                var dailySleepDurations: [Date: TimeInterval] = [:]
                
                for sample in sleepSamples {
                    // Only count periods categorized as asleep (asleepCore, asleepDeep, asleepREM or generic asleep)
                    let isAsleep = sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                                   sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    
                    if isAsleep {
                        let duration = sample.endDate.timeIntervalSince(sample.startDate)
                        let dayStart = calendar.startOfDay(for: sample.startDate)
                        dailySleepDurations[dayStart, default: 0] += duration
                    }
                }
                
                guard !dailySleepDurations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let totalDurations = dailySleepDurations.values.reduce(0, +)
                let avgHours = (totalDurations / Double(dailySleepDurations.count)) / 3600.0
                continuation.resume(returning: avgHours)
            }
            self.healthStore.execute(query)
        }
    }
}
