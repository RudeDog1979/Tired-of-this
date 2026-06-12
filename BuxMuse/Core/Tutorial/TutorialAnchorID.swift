//
//  TutorialAnchorID.swift
//  BuxMuse
//

import Foundation

enum TutorialAnchorID: String, Hashable, CaseIterable {
    case homeBudgetRing
    case homeIncomeButton
    case homeExpenseButton
    case addIncomeAmount
    case addExpenseMerchant
    case addExpenseCategory
    case addExpenseScan
    case addExpenseSave
    case settingsOverview
    case settingsBudgetRow
    case settingsBudgetPayPeriod
    case settingsStudioRow
    case settingsAppearanceRow
    case settingsBackupRow
    case settingsStudioDetail
    case settingsAppearanceDetail
    case settingsBackupDetail
    case studioHubHeader
    case studioMoneyEntry
    case expensesTabHeader
    case homeFinish
}

extension TutorialAnchorID {
    /// Anchors inside Add Expense / Add Income sheets — overlay must render in the sheet, not under it.
    var hostsInSheet: Bool {
        switch self {
        case .addIncomeAmount, .addExpenseMerchant, .addExpenseCategory, .addExpenseScan, .addExpenseSave:
            return true
        default:
            return false
        }
    }

    /// Anchors on pushed Settings drill-in screens — overlay renders inside the detail pane.
    var hostsInSettingsDetail: Bool {
        switch self {
        case .settingsBudgetPayPeriod, .settingsStudioDetail, .settingsAppearanceDetail, .settingsBackupDetail:
            return true
        default:
            return false
        }
    }
}

extension SettingsDestinationType {
    var tutorialAnchorID: TutorialAnchorID? {
        switch self {
        case .budgets: return .settingsBudgetRow
        case .studio: return .settingsStudioRow
        case .appearance: return .settingsAppearanceRow
        case .data: return .settingsBackupRow
        default: return nil
        }
    }
}
