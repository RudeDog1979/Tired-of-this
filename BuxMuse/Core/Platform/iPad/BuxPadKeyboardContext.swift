//
//  BuxPadKeyboardContext.swift
//  BuxMuse — Active tab/context for iPad keyboard shortcut labels and routing.
//

import SwiftUI

struct BuxPadKeyboardContext: Equatable {
    var selectedTab: AppTab = .home
    var studioMode: StudioMode = .simple
    var studioDestination: String?

    var newItemMenuTitle: String {
        switch selectedTab {
        case .home, .expense:
            return "New Expense"
        case .studio:
            switch studioMode {
            case .simple:
                return "Log Time"
            case .pro:
                return "Studio Quick Action"
            }
        case .settings:
            return "New Expense"
        }
    }

    var findMenuTitle: String {
        switch selectedTab {
        case .home, .expense:
            return "Search Expenses"
        case .studio:
            return "Focus Studio Search"
        case .settings:
            return "Focus Settings"
        }
    }

    var closeMenuTitle: String {
        "Dismiss"
    }

    var isNewItemEnabled: Bool {
        switch selectedTab {
        case .settings:
            return false
        case .studio where studioMode == .pro:
            return false
        default:
            return true
        }
    }

    var isFindEnabled: Bool {
        switch selectedTab {
        case .home, .expense:
            return true
        case .studio, .settings:
            return false
        }
    }
}
