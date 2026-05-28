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
