//
//  BuxPadStudioHost.swift
//  BuxMuse — iPad Studio: tool sidebar left, Command Center / tools right.
//

import SwiftUI

struct BuxPadStudioHost: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var studioSelection: BuxPadStudioDestination? = .commandCenter
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if settingsStore.studioMode == .pro {
                proSplitStudio
            } else if settingsStore.studioMode == .simple {
                BuxPadSimpleStudioHost()
            } else {
                StudioHubView()
            }
        }
        .buxPadDebouncedBrainResize(columnVisibility: columnVisibility)
        .onAppear {
            restoreStudioSelectionIfNeeded()
        }
        .onChange(of: studioSelection) { _, newValue in
            padNavigationBrain.selectedStudioDestination = newValue?.rawValue
        }
    }

    private var proSplitStudio: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                BuxPadStudioSidebar(selection: $studioSelection)
                    .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                    .buxPadSplitSidebarColumnWidth(layoutMode: layoutMode)
            } detail: {
                studioDetailColumn
                    .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                    .environment(\.buxPadStudioUsesSplitLayout, true)
                    .buxPadStudioSplitDetailChrome()
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BuxPadExternalDisplayMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    BuxPadOpenStudioWindowButton(destination: studioSelection)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.studioEnhancedTint, true)
    }

    @ViewBuilder
    private var studioDetailColumn: some View {
        if let studioSelection {
            BuxPadStudioDetailRouter(destination: studioSelection)
        } else {
            ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                BuxPadDetailEmptyState(
                    title: "Studio",
                    systemImage: "briefcase.fill",
                    message: "Choose a tool from the sidebar."
                )
            }
        }
    }

    private func restoreStudioSelectionIfNeeded() {
        guard settingsStore.studioMode == .pro else { return }
        if let raw = padNavigationBrain.selectedStudioDestination,
           let restored = BuxPadStudioDestination(rawValue: raw) {
            studioSelection = restored
        } else if studioSelection == nil {
            studioSelection = .commandCenter
        }
        padNavigationBrain.selectedStudioDestination = studioSelection?.rawValue
    }
}
