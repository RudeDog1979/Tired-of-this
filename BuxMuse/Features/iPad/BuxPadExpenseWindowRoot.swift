//
//  BuxPadExpenseWindowRoot.swift
//  BuxMuse — Auxiliary iPad window: Expenses split only.
//

import SwiftUI

struct BuxPadExpenseWindowRoot: View {
    let sessionId: UUID
    @ObservedObject var container: AppContainer

    private var padBrain: BuxPadNavigationBrain {
        container.padSceneBrainRegistry.brain(for: sessionId)
    }

    var body: some View {
        BuxPadExpenseHost()
            .buxPadEnvironment()
        .buxPadReportsContainerMetrics()
        .buxPadRootChrome(isPad: true)
        .buxPadCommandBridge(isPad: true)
        .buxPadKeyboardContextSync(isPad: true)
        .buxPadEscapeKeyHandler(isPad: true)
        .buxPadDebouncedBrainResize(isPad: true)
        .buxPadAuxiliaryWindowChrome(kind: .expense)
        .onAppear {
            padBrain.updateKeyboardContext(
                selectedTab: .expense,
                studioMode: SettingsStore.shared.studioMode,
                studioDestination: padBrain.selectedStudioDestination
            )
        }
        .userActivity(BuxPadSceneActivity.expenseWindow) { activity in
                activity.title = "BuxMuse Expenses"
                activity.isEligibleForSearch = false
                activity.isEligibleForHandoff = false
                activity.userInfo = BuxPadSceneRestoration.userInfo(
                    sessionId: sessionId,
                    snapshot: padBrain.exportSnapshot()
                )
            }
            .onContinueUserActivity(BuxPadSceneActivity.expenseWindow) { activity in
                guard let snapshot = BuxPadSceneRestoration.snapshot(from: activity.userInfo) else { return }
                padBrain.applySnapshot(snapshot)
            }
    }
}
