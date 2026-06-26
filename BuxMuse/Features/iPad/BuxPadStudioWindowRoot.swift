//
//  BuxPadStudioWindowRoot.swift
//  BuxMuse — Auxiliary iPad window: Studio tool column.
//

import SwiftUI

struct BuxPadStudioWindowRoot: View {
    let payload: BuxPadStudioWindowPayload
    @ObservedObject var container: AppContainer

    private var padBrain: BuxPadNavigationBrain {
        container.padSceneBrainRegistry.brain(for: payload.sessionId)
    }

    var body: some View {
        BuxPadStudioWindowContent(initialDestination: payload.destination)
            .buxPadEnvironment()
            .buxPadReportsContainerMetrics()
            .buxPadRootChrome(isPad: true)
            .buxPadCommandBridge(isPad: true)
            .buxPadKeyboardContextSync(isPad: true)
            .buxPadEscapeKeyHandler(isPad: true)
            .buxPadDebouncedBrainResize(isPad: true)
            .buxPadAuxiliaryWindowChrome(kind: .studio)
            .onAppear {
                padBrain.updateKeyboardContext(
                    selectedTab: .studio,
                    studioMode: SettingsStore.shared.studioMode,
                    studioDestination: padBrain.selectedStudioDestination ?? payload.destination
                )
            }
            .userActivity(BuxPadSceneActivity.studioWindow) { activity in
                activity.title = "BuxMuse Studio"
                activity.isEligibleForSearch = false
                activity.isEligibleForHandoff = false
                activity.userInfo = BuxPadSceneRestoration.userInfo(
                    sessionId: payload.sessionId,
                    snapshot: padBrain.exportSnapshot(),
                    studioDestination: payload.destination
                )
            }
            .onContinueUserActivity(BuxPadSceneActivity.studioWindow) { activity in
                guard let snapshot = BuxPadSceneRestoration.snapshot(from: activity.userInfo) else { return }
                padBrain.applySnapshot(snapshot)
            }
    }
}

/// Studio-only auxiliary window — avoids TabView; restores destination from payload / brain.
private struct BuxPadStudioWindowContent: View {
    let initialDestination: String?
    @Environment(\.buxLayoutMode) private var layoutMode
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var studioSelection: BuxPadStudioDestination?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if settingsStore.studioEnabled, settingsStore.studioMode == .pro {
                proSplitStudio
            } else if settingsStore.studioEnabled, settingsStore.studioMode == .simple {
                BuxPadSimpleStudioHost()
            } else {
                BuxPadDetailEmptyState(
                    title: "Studio",
                    systemImage: "briefcase.fill",
                    message: "Enable Studio in Settings to use this window."
                )
            }
        }
        .onAppear {
            if settingsStore.studioMode == .pro {
                if studioSelection == nil {
                    if let raw = initialDestination ?? padNavigationBrain.selectedStudioDestination,
                       let dest = BuxPadStudioDestination(rawValue: raw) {
                        studioSelection = dest
                    } else {
                        studioSelection = .commandCenter
                    }
                }
                padNavigationBrain.selectedStudioDestination = studioSelection?.rawValue
            } else if settingsStore.studioMode == .simple {
                if let raw = initialDestination,
                   BuxPadSimpleStudioDestination(rawValue: raw) != nil {
                    padNavigationBrain.selectedStudioDestination = raw
                } else if BuxPadSimpleStudioDestination(
                    rawValue: padNavigationBrain.selectedStudioDestination ?? ""
                ) == nil {
                    padNavigationBrain.selectedStudioDestination = BuxPadSimpleStudioDestination.home.rawValue
                }
            }
        }
        .onChange(of: studioSelection) { _, newValue in
            padNavigationBrain.selectedStudioDestination = newValue?.rawValue
        }
    }

    private var proSplitStudio: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()
                .animation(nil, value: studioSelection)

            NavigationSplitView(columnVisibility: $columnVisibility) {
                BuxPadStudioSidebar(selection: $studioSelection)
                    .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                    .buxPadSplitSidebarColumnWidth(layoutMode: layoutMode)
            } detail: {
                BuxPadSplitDetailCanvas(selection: studioSelection) {
                    Group {
                        if let studioSelection {
                            BuxPadStudioDetailRouter(destination: studioSelection)
                        } else {
                            BuxPadDetailEmptyState(
                                title: "Studio",
                                systemImage: "briefcase.fill",
                                message: "Choose a tool from the sidebar."
                            )
                        }
                    }
                    .buxPadSplitDetailTransition()
                }
                .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                .environment(\.buxPadStudioUsesSplitLayout, true)
                .buxPadStudioSplitDetailChrome()
            }
            .buxPadSplitDetailNavigationAnimation(value: studioSelection)
            .navigationSplitViewStyle(.balanced)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.studioEnhancedTint, true)
    }
}
