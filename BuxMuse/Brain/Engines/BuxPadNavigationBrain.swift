//
//  BuxPadNavigationBrain.swift
//  BuxMuse — iPad-only navigation/presentation state. No business data.
//

import SwiftUI
import Combine

@MainActor
final class BuxPadNavigationBrain: ObservableObject {
    @Published var selectedExpenseId: UUID?
    @Published var selectedStudioDestination: String?
    @Published var selectedSettingsPath: String?
    @Published var isInspectorColumnVisible: Bool = true

    @Published var activePresentation: BuxPadPresentationTrigger?
    @Published private(set) var resolvedSurface: BuxPadPresentationSurface = .sheetLarge

    /// iPad keyboard bridge — incremented on each ⌘ shortcut (see BuxPadKeyboardCommands).
    @Published private(set) var keyboardCommandToken: Int = 0
    @Published private(set) var lastKeyboardCommand: BuxPadKeyboardCommand?
    @Published private(set) var keyboardContext = BuxPadKeyboardContext()

    /// Debounced container resize — hosts bump after split drag / Stage Manager resize settles.
    @Published private(set) var containerResizeToken: Int = 0
    @Published private(set) var lastContainerWidth: CGFloat = 0

    // MARK: - External display (Step 7)

    @Published private(set) var externalDisplayConnection: BuxPadExternalDisplayConnection = .disconnected
    @Published var activeExternalPresentation: BuxPadExternalPresentationKind?
    @Published private(set) var externalPresentationSessionId: UUID?
    @Published var externalInvoiceContext: InvoiceRenderContext?
    @Published var externalInvoiceTargetId: UUID?
    @Published private(set) var externalPresentationRevision: Int = 0

    /// Expense delete redo — set after ⌘Z undo; ⌘⇧Z re-deletes (pad layer only).
    @Published private(set) var expenseRedoCandidate: ExpenseRecord?

    var canExpenseRedo: Bool { expenseRedoCandidate != nil }

    func resolvePresentation(
        trigger: BuxPadPresentationTrigger,
        layoutMode: BuxLayoutMode
    ) {
        activePresentation = trigger
        resolvedSurface = BuxAdaptivePresentation.surface(
            for: trigger,
            layoutMode: layoutMode,
            isPad: BuxPadIdiom.isPad
        )
    }

    func clearPresentation() {
        activePresentation = nil
    }

    func selectExpense(_ id: UUID?) {
        selectedExpenseId = id
        if id != nil {
            resolvePresentation(trigger: .expenseDetail, layoutMode: .regular)
        }
    }

    func clearExpenseSelection() {
        selectedExpenseId = nil
    }

    /// Arrow keys / List menu — cycle selection in the visible expense list.
    func postPadKeyboardCommand(_ command: BuxPadKeyboardCommand) {
        guard BuxPadIdiom.isPad else { return }
        lastKeyboardCommand = command
        keyboardCommandToken &+= 1
    }

    func updateKeyboardContext(
        selectedTab: AppTab,
        studioMode: StudioMode,
        studioDestination: String?
    ) {
        guard BuxPadIdiom.isPad else { return }
        keyboardContext = BuxPadKeyboardContext(
            selectedTab: selectedTab,
            studioMode: studioMode,
            studioDestination: studioDestination
        )
    }

    /// Re-resolve presentation policy after debounced resize without clearing selection.
    func notifyContainerResize(width: CGFloat, layoutMode: BuxLayoutMode) {
        guard BuxPadIdiom.isPad else { return }
        lastContainerWidth = width
        containerResizeToken &+= 1
        if let trigger = activePresentation {
            resolvePresentation(trigger: trigger, layoutMode: layoutMode)
        }
    }

    func handleExternalScreensChanged(extraScreenCount: Int) {
        guard BuxPadIdiom.isPad else { return }
        if extraScreenCount > 0 {
            externalDisplayConnection = .connected(extraScreens: extraScreenCount)
        } else {
            handleExternalDisplayDisconnected()
        }
    }

    /// Disconnect external display — preserves iPad draft/selection (no data loss).
    func handleExternalDisplayDisconnected() {
        guard BuxPadIdiom.isPad else { return }
        externalDisplayConnection = .disconnected
        externalPresentationSessionId = nil
        externalPresentationRevision &+= 1
    }

    func requestExternalPresentation(_ kind: BuxPadExternalPresentationKind) {
        guard BuxPadIdiom.isPad else { return }
        activeExternalPresentation = kind
        externalPresentationSessionId = UUID()
        externalPresentationRevision &+= 1
    }

    func updateExternalInvoiceContext(_ context: InvoiceRenderContext?, targetInvoiceId: UUID? = nil) {
        guard BuxPadIdiom.isPad else { return }
        externalInvoiceContext = context
        externalInvoiceTargetId = targetInvoiceId
        externalPresentationRevision &+= 1
    }

    func clearExternalPresentation() {
        guard BuxPadIdiom.isPad else { return }
        activeExternalPresentation = nil
        externalPresentationSessionId = nil
        externalPresentationRevision &+= 1
    }

    func stashExpenseRedoCandidate(_ record: ExpenseRecord) {
        guard BuxPadIdiom.isPad else { return }
        expenseRedoCandidate = record
    }

    func clearExpenseRedoCandidate() {
        expenseRedoCandidate = nil
    }

    func selectAdjacentExpense(in records: [ExpenseRecord], direction: Int) {
        guard !records.isEmpty else {
            clearExpenseSelection()
            return
        }
        guard let currentId = selectedExpenseId,
              let index = records.firstIndex(where: { $0.id == currentId }) else {
            selectExpense(records.first?.id)
            return
        }
        let nextIndex = index + direction
        guard records.indices.contains(nextIndex) else { return }
        selectExpense(records[nextIndex].id)
    }
}
