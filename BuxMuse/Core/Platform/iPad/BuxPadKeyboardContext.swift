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
            return BuxCatalogLabel.string("New Expense", locale: BuxInterfaceLocale.currentInterfaceLocale)
        case .studio:
            switch studioMode {
            case .simple:
                return BuxCatalogLabel.string("Log Time", locale: BuxInterfaceLocale.currentInterfaceLocale)
            case .pro:
                return BuxCatalogLabel.string("Studio Quick Action", locale: BuxInterfaceLocale.currentInterfaceLocale)
            }
        case .settings:
            return BuxCatalogLabel.string("New Expense", locale: BuxInterfaceLocale.currentInterfaceLocale)
        }
    }

    var findMenuTitle: String {
        switch selectedTab {
        case .home, .expense:
            return BuxCatalogLabel.string("Search Expenses", locale: BuxInterfaceLocale.currentInterfaceLocale)
        case .studio:
            return BuxCatalogLabel.string("Focus Studio Search", locale: BuxInterfaceLocale.currentInterfaceLocale)
        case .settings:
            return BuxCatalogLabel.string("Focus Settings", locale: BuxInterfaceLocale.currentInterfaceLocale)
        }
    }

    var closeMenuTitle: String {
        BuxCatalogLabel.string("Dismiss", locale: BuxInterfaceLocale.currentInterfaceLocale)
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
