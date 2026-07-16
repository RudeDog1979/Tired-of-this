//
//  BuxPresenceStreakStore.swift
//  BuxMuse
//
//  Persisted presence streak + lifetime Vault Titles.
//

import Combine
import Foundation

@MainActor
final class BuxPresenceStreakStore: ObservableObject {
    static let shared = BuxPresenceStreakStore()

    @Published private(set) var state = BuxPresenceStreakState()
    @Published var showDailyPopup = false
    @Published var showTitlesSheet = false
    @Published private(set) var newlyUnlockedTitleIDs: [BuxPresenceTitleID] = []

    private let storageKey = "buxmuse.presence.streak.v2"
    private let legacyStorageKey = "buxmuse.presence.streak.v1"
    private var isLoaded = false

    private init() {
        load()
    }

    var currentLength: Int { state.length }
    var bestLength: Int { state.bestLength }
    var weekDayIndex: Int { state.weekDayIndex }
    var lifetimeOpenDayCount: Int { state.lifetimeOpenDayCount }
    var highestTitle: BuxPresenceTitleID? { state.highestTitle }

    func recordOpenIfEligible(
        hasCompletedOnboarding: Bool,
        hasActiveSubscription: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard hasCompletedOnboarding, hasActiveSubscription else { return }

        let todayKey = BuxPresenceDayKey.dayKey(for: now, calendar: calendar)
        let monthKey = BuxPresenceDayKey.monthKey(for: now, calendar: calendar)
        let outcome = BuxPresenceDayKey.determineOutcome(
            lastOpenDayKey: state.lastOpenDayKey,
            now: now,
            calendar: calendar
        )

        var next = state

        switch outcome {
        case .alreadyCompletedToday:
            break
        case .firstOpen, .streakBroken:
            next.length = 1
            next.lastOpenDayKey = todayKey
            next.lifetimeOpenDayCount += 1
            if !next.openedMonthKeys.contains(monthKey) {
                next.openedMonthKeys.append(monthKey)
            }
        case .streakContinues:
            next.length = max(1, next.length) + 1
            next.lastOpenDayKey = todayKey
            next.lifetimeOpenDayCount += 1
            if !next.openedMonthKeys.contains(monthKey) {
                next.openedMonthKeys.append(monthKey)
            }
        }

        next.bestLength = max(next.bestLength, next.length)

        let freshTitles = evaluateTitles(state: next, now: now)
        if !freshTitles.isEmpty {
            next.unlockedTitles.append(contentsOf: freshTitles)
            newlyUnlockedTitleIDs = freshTitles.map(\.titleID)
        } else if outcome != .alreadyCompletedToday {
            newlyUnlockedTitleIDs = []
        }

        state = next
        persist()

        let shouldPopup = next.lastPopupDayKey != todayKey
        if shouldPopup {
            showDailyPopup = true
        }
    }

    func markDailyPopupShown(now: Date = Date(), calendar: Calendar = .current) {
        let todayKey = BuxPresenceDayKey.dayKey(for: now, calendar: calendar)
        state.lastPopupDayKey = todayKey
        showDailyPopup = false
        persist()
    }

    func openTitlesSheet() {
        showTitlesSheet = true
    }

    func dismissTitlesSheet() {
        showTitlesSheet = false
    }

    func isUnlocked(_ title: BuxPresenceTitleID) -> Bool {
        state.unlockedTitles.contains { $0.titleID == title }
    }

    func unlockDate(for title: BuxPresenceTitleID) -> Date? {
        state.unlockedTitles
            .first { $0.titleID == title }
            .map(\.unlockedAt)
    }

    func progressHint(for title: BuxPresenceTitleID) -> String? {
        guard !isUnlocked(title) else { return nil }
        switch title {
        case .pennyPincher:
            return nil
        case .expenseExplorer:
            return streakProgress(needed: 3)
        case .receiptWrangler:
            return streakProgress(needed: 7)
        case .budgetBoss:
            return streakProgress(needed: 14)
        case .coinCollector:
            return streakProgress(needed: 30)
        case .billBreaker:
            return streakProgress(needed: 60)
        case .savingsSamurai:
            return streakProgress(needed: 90)
        case .debtDestroyer:
            let have = lifetimeOpenDayCount
            return "\(min(have, 100))/100"
        case .wealthWarrior:
            return streakProgress(needed: 180)
        case .cashKing:
            return streakProgress(needed: 365)
        case .goldenGoal:
            let have = Set(state.openedMonthKeys).count
            return "\(min(have, 12))/12"
        case .estateEmperor:
            return nil
        }
    }

    func resetAll() {
        state = BuxPresenceStreakState()
        newlyUnlockedTitleIDs = []
        showDailyPopup = false
        showTitlesSheet = false
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
    }

    // MARK: - Private

    private func streakProgress(needed: Int) -> String {
        "\(min(bestLength, needed))/\(needed)"
    }

    private func evaluateTitles(
        state: BuxPresenceStreakState,
        now: Date
    ) -> [BuxPresenceTitleUnlock] {
        var fresh: [BuxPresenceTitleUnlock] = []
        let owned = Set(state.unlockedTitles.map(\.titleID))
        for title in BuxPresenceTitleID.allCases.sorted() {
            guard !owned.contains(title) else { continue }
            guard title.isSatisfied(by: state) else { continue }
            fresh.append(BuxPresenceTitleUnlock(titleID: title, unlockedAt: now))
        }
        return fresh
    }

    private func load() {
        defer { isLoaded = true }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(BuxPresenceStreakState.self, from: data) {
            state = decoded
            return
        }
        // Soft-migrate streak length from v1 if present; drop monthly badges.
        if let legacy = UserDefaults.standard.data(forKey: legacyStorageKey),
           let json = try? JSONSerialization.jsonObject(with: legacy) as? [String: Any] {
            var migrated = BuxPresenceStreakState()
            migrated.length = json["length"] as? Int ?? 0
            migrated.bestLength = json["bestLength"] as? Int ?? migrated.length
            migrated.lastOpenDayKey = json["lastOpenDayKey"] as? String
            migrated.lastPopupDayKey = json["lastPopupDayKey"] as? String
            if let days = json["openDaysThisMonth"] as? [String] {
                migrated.lifetimeOpenDayCount = max(migrated.length, days.count)
            } else if migrated.length > 0 {
                migrated.lifetimeOpenDayCount = migrated.length
            }
            if let month = json["monthKey"] as? String {
                migrated.openedMonthKeys = [month]
            }
            state = migrated
            // Re-evaluate titles from migrated stats
            let fresh = evaluateTitles(state: state, now: Date())
            if !fresh.isEmpty {
                state.unlockedTitles = fresh
            }
            persist()
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
