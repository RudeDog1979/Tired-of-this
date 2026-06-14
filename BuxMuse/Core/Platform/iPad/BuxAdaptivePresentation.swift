//
//  BuxAdaptivePresentation.swift
//  BuxMuse — iPad presentation mode resolver. UI routing only — no business logic.
//

import SwiftUI

enum BuxPadPresentationSurface: Equatable {
    case splitColumn
    case sheetLarge
    case sheetMedium
    case popover
    case fullScreenCover
    case rootOverlay
}

enum BuxPadPresentationTrigger: Equatable {
    case expenseDetail
    case addExpense
    case subscriptionHub
    case debtHub
    case goalDetail
    case insightDetail
    case studioTool
    case categoryPicker
    case notePicker
    case share
    case onboarding
}

enum BuxAdaptivePresentation {
    static func surface(
        for trigger: BuxPadPresentationTrigger,
        layoutMode: BuxLayoutMode,
        isPad: Bool
    ) -> BuxPadPresentationSurface {
        guard isPad else {
            switch trigger {
            case .expenseDetail: return .fullScreenCover
            case .subscriptionHub, .goalDetail, .insightDetail, .debtHub: return .rootOverlay
            case .categoryPicker, .notePicker: return .sheetMedium
            case .share: return .sheetLarge
            default: return .sheetLarge
            }
        }

        switch trigger {
        case .expenseDetail, .studioTool: return .splitColumn
        case .subscriptionHub, .goalDetail, .insightDetail, .debtHub: return .splitColumn
        case .share: return .popover
        case .onboarding: return .fullScreenCover
        case .addExpense:
            return layoutMode == .regular ? .sheetLarge : .sheetMedium
        case .categoryPicker, .notePicker:
            return layoutMode == .regular ? .popover : .sheetMedium
        }
    }
}
