//
//  BuxPresenceStreakModels.swift
//  BuxMuse
//
//  Calendar-day presence streak + lifetime Vault Titles.
//

import Foundation

enum BuxPresenceStreakOutcome: Equatable {
    case alreadyCompletedToday
    case streakContinues
    case streakBroken
    case firstOpen
}

/// Lifetime Vault Titles — highest `rank` wins the avatar pin.
enum BuxPresenceTitleID: String, Codable, CaseIterable, Identifiable, Comparable {
    case pennyPincher
    case expenseExplorer
    case receiptWrangler
    case budgetBoss
    case coinCollector
    case billBreaker
    case savingsSamurai
    case debtDestroyer
    case wealthWarrior
    case cashKing
    case goldenGoal
    case estateEmperor

    var id: String { rawValue }

    /// Higher = better pin on avatar.
    var rank: Int {
        switch self {
        case .pennyPincher: return 1
        case .expenseExplorer: return 2
        case .receiptWrangler: return 3
        case .budgetBoss: return 4
        case .coinCollector: return 5
        case .billBreaker: return 6
        case .savingsSamurai: return 7
        case .debtDestroyer: return 8
        case .wealthWarrior: return 9
        case .cashKing: return 10
        case .goldenGoal: return 11
        case .estateEmperor: return 12
        }
    }

    var titleKey: String {
        switch self {
        case .pennyPincher: return "Penny Pincher"
        case .expenseExplorer: return "Expense Explorer"
        case .receiptWrangler: return "Receipt Wrangler"
        case .budgetBoss: return "Budget Boss"
        case .coinCollector: return "Coin Collector"
        case .billBreaker: return "Bill Breaker"
        case .savingsSamurai: return "Savings Samurai"
        case .debtDestroyer: return "Debt Destroyer"
        case .wealthWarrior: return "Wealth Warrior"
        case .cashKing: return "Cash King"
        case .goldenGoal: return "Golden Goal"
        case .estateEmperor: return "Estate Emperor"
        }
    }

    var emoji: String {
        switch self {
        case .pennyPincher: return "🪙"
        case .expenseExplorer: return "🧭"
        case .receiptWrangler: return "🧾"
        case .budgetBoss: return "📋"
        case .coinCollector: return "💰"
        case .billBreaker: return "💸"
        case .savingsSamurai: return "⚔️"
        case .debtDestroyer: return "💥"
        case .wealthWarrior: return "🛡️"
        case .cashKing: return "👑"
        case .goldenGoal: return "🎯"
        case .estateEmperor: return "🏰"
        }
    }

    var criterionSummaryKey: String {
        switch self {
        case .pennyPincher: return "First open"
        case .expenseExplorer: return "3-day streak"
        case .receiptWrangler: return "7-day streak"
        case .budgetBoss: return "14-day streak"
        case .coinCollector: return "30-day streak"
        case .billBreaker: return "60-day streak"
        case .savingsSamurai: return "90-day streak"
        case .debtDestroyer: return "100 open days"
        case .wealthWarrior: return "180-day streak"
        case .cashKing: return "365-day streak"
        case .goldenGoal: return "12 different months"
        case .estateEmperor: return "Cash King + Golden Goal"
        }
    }

    static func < (lhs: BuxPresenceTitleID, rhs: BuxPresenceTitleID) -> Bool {
        lhs.rank < rhs.rank
    }

    func isSatisfied(by state: BuxPresenceStreakState) -> Bool {
        switch self {
        case .pennyPincher:
            return state.lifetimeOpenDayCount >= 1
        case .expenseExplorer:
            return state.bestLength >= 3
        case .receiptWrangler:
            return state.bestLength >= 7
        case .budgetBoss:
            return state.bestLength >= 14
        case .coinCollector:
            return state.bestLength >= 30
        case .billBreaker:
            return state.bestLength >= 60
        case .savingsSamurai:
            return state.bestLength >= 90
        case .debtDestroyer:
            return state.lifetimeOpenDayCount >= 100
        case .wealthWarrior:
            return state.bestLength >= 180
        case .cashKing:
            return state.bestLength >= 365
        case .goldenGoal:
            return Set(state.openedMonthKeys).count >= 12
        case .estateEmperor:
            return state.bestLength >= 365 && Set(state.openedMonthKeys).count >= 12
        }
    }
}

struct BuxPresenceTitleUnlock: Codable, Equatable, Identifiable {
    var id: String { titleID.rawValue }
    var titleID: BuxPresenceTitleID
    var unlockedAt: Date
}

struct BuxPresenceStreakState: Codable, Equatable {
    var length: Int = 0
    var bestLength: Int = 0
    var lastOpenDayKey: String?
    var lastPopupDayKey: String?
    /// Distinct calendar days the app was opened (lifetime).
    var lifetimeOpenDayCount: Int = 0
    /// Distinct `yyyy-MM` months with at least one open.
    var openedMonthKeys: [String] = []
    var unlockedTitles: [BuxPresenceTitleUnlock] = []

    var weekDayIndex: Int {
        guard length > 0 else { return 0 }
        let mod = length % 7
        return mod == 0 ? 7 : mod
    }

    var highestTitle: BuxPresenceTitleID? {
        unlockedTitles.map(\.titleID).max()
    }
}

enum BuxPresenceDayKey {
    private static func formatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        formatter(timeZone: calendar.timeZone).string(from: date)
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func determineOutcome(
        lastOpenDayKey: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> BuxPresenceStreakOutcome {
        guard let lastOpenDayKey else { return .firstOpen }
        let today = dayKey(for: now, calendar: calendar)
        if lastOpenDayKey == today {
            return .alreadyCompletedToday
        }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            return .streakBroken
        }
        if lastOpenDayKey == dayKey(for: yesterday, calendar: calendar) {
            return .streakContinues
        }
        return .streakBroken
    }
}
