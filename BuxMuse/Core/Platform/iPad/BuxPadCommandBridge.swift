//
//  BuxPadCommandBridge.swift
//  BuxMuse — Dispatches iPad keyboard commands to coordinators (no iPhone path).
//

import SwiftUI

struct BuxPadCommandBridge: ViewModifier {
    let isPad: Bool

    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry
    @EnvironmentObject private var navigation: NavigationCoordinator
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var goalsSheetCoordinator: GoalsSheetCoordinator
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .onChange(of: padBrain.keyboardCommandToken) { _, _ in
                guard isPad, let command = padBrain.lastKeyboardCommand else { return }
                dispatch(command)
            }
    }

    @MainActor
    private func dispatch(_ command: BuxPadKeyboardCommand) {
        switch command {
        case .newExpense:
            dispatchContextualNewItem()
        case .focusSearch:
            dispatchContextualFind()
        case .save:
            SettingsStore.shared.save()
        case .openSettings:
            navigation.openProfileSettings()
        case .close:
            dismissTopLayerOrPanels()
        case .undo:
            if let record = brain.expenseUndoOffer {
                padBrain.stashExpenseRedoCandidate(record)
            }
            try? brain.performExpenseUndo()
        case .redo:
            guard let record = padBrain.expenseRedoCandidate else { return }
            padBrain.clearExpenseRedoCandidate()
            try? brain.deleteExpense(id: record.id)
        case .selectPreviousRow:
            guard navigation.selectedTab == .expense else { return }
            padBrain.selectAdjacentExpense(in: brain.expenseRecords, direction: -1)
        case .selectNextRow:
            guard navigation.selectedTab == .expense else { return }
            padBrain.selectAdjacentExpense(in: brain.expenseRecords, direction: 1)
        case .openExpenseWindow:
            guard !padSceneBrainRegistry.isAuxiliary(padBrain) else { return }
            BuxPadWindowLauncher.openExpenseWindow(
                from: padBrain,
                registry: padSceneBrainRegistry,
                openWindow: openWindow
            )
        case .openStudioWindow:
            guard !padSceneBrainRegistry.isAuxiliary(padBrain) else { return }
            BuxPadWindowLauncher.openStudioWindow(
                destination: padBrain.selectedStudioDestination,
                from: padBrain,
                registry: padSceneBrainRegistry,
                openWindow: openWindow
            )
        }
    }

    @MainActor
    private func dispatchContextualNewItem() {
        switch padBrain.keyboardContext.selectedTab {
        case .home, .expense:
            navigation.requestPadNewExpense()
        case .studio:
            guard padBrain.keyboardContext.studioMode == .simple else { return }
            navigation.openStudioLogTime()
        case .settings:
            break
        }
    }

    @MainActor
    private func dispatchContextualFind() {
        switch padBrain.keyboardContext.selectedTab {
        case .home, .expense:
            navigation.requestPadFocusSearch()
        case .studio, .settings:
            break
        }
    }

    @MainActor
    private func dismissTopLayerOrPanels() {
        let dismissed = BuxPadEscapeStack.dismissTopLayer(
            navigation: navigation,
            goals: goalsSheetCoordinator,
            insights: insightsViewModel,
            padBrain: padBrain
        )
        guard !dismissed else { return }

        navigation.dismissExpenseSearch()
        navigation.closeSubscriptionHub()
        goalsSheetCoordinator.dismissGoalDetail()
        insightsViewModel.dismissInsightDetail()
        padBrain.clearPresentation()
    }
}

extension View {
    /// Attach on root — routes ⌘ shortcuts from BuxPadKeyboardCommands (no-op when not iPad).
    func buxPadCommandBridge(isPad: Bool) -> some View {
        modifier(BuxPadCommandBridge(isPad: isPad))
    }
}
