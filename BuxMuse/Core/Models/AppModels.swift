//
//  AppModels.swift
//  BuxMuse
//
//  All shared data models for the app.
//

import SwiftUI

// MARK: - App Navigation Tabs

enum AppTab {
    case home
    case expense
    case studio
    case settings
}

extension AppTab {
    var nativeTabTitle: String {
        switch self {
        case .home: return "Home"
        case .expense: return "Expenses"
        case .studio: return "Studio"
        case .settings: return "Settings"
        }
    }

    var nativeTabSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .expense: return "wallet.pass.fill"
        case .studio: return "laptopcomputer"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Spending Category

struct SpendingCategoryItem: Identifiable {
    let id = UUID()
    let title: String
    let amount: String
    let percentage: String
    let transactionsCount: Int
    let icon: String
    let color: Color
}

// MARK: - Transaction

struct TransactionItem: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let amount: String
    let icon: String
    let isPositive: Bool
}
